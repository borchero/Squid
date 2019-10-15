# Retriers

Retriers are a very useful tool for repeating requests that have failed. In Squid, they can be used in a variety of contexts. Some examples are the following:

* If an error occurs due to a missing internet connection or rate limiting, the request can be retried multiple times with exponential backoff.
* If an error occurs due to an expired token and results in a 401 response, the token can be refreshed and the request is retried with the new token.

## How to Use Retriers

Retriers are defined at the API level - the justification being that e.g. authorization is implemented equally for all calls against an API.

In order to use a retrier, the `HttpService` provides a `HttpService.retrierFactory` property. Note that a new retrier is created per request to enable *stateful* retriers (e.g. exponential backoff). Creating a factory from a retrier is, however, very straightforward as you will see in the following.

The retrier itself needs to conform to the `Retrier` protocol which defines a single `Retrier.retry(_:failingWith:)` method that possibly retries a failed request.

To showcase how to use retriers in practice, we will consider the `BackoffRetrier` that Squid provides out-of-the-box as well as implement our own retrier for Authorization.

## Exponential Backoff

As applying an exponential backoff to a failed request can be standardized, i.e. is not dependent on a particular API, it is included in Squid directly.

As pointed out above, retriers need to be included into the API, so we modify our service from the first guide as follows:

```swift
struct MyApi: HttpService {

    var apiUrl: UrlConvertible {
        "jsonplaceholder.typicode.com"
    }

    var retrierFactory: RetrierFactory {
        BackoffRetrier.factory()
    }
}
```

As a result, all requests that are now scheduled against the API will be retried when particular errors occur (e.g. "no connection", 429 status code, ..., see `BackoffRetrier.defaultRetryCondition(_:)`).

**In fact, you do not need to change anything else for this to work. You can schedule requests just as before.**

## Refreshing Tokens

Refreshing tokens for accessing protected resources is probably one of the most common use cases for retriers when targeting secure APIs. However, Squid does not include this feature out-of-the-box since the particular implementation is highly dependent on a particular API.

In the following, we will walk you through the process of setting up services and requests that enable retrying requests for authentication. Throughout, we assume the following:

* We have two API endpoints: (A) one for *authentication* which can be accessed easily and (B) one for *accessing protected resources* where we need to authenticate.
* Authentication is performed via an *access token* that is passed via the HTTP `Authorization` header. Once received, this token is, however, valid for a short period of time only (e.g. 10 minutes).
* To request a new access token without passing user credentials (e.g. username/password), we have a *refresh token* that does not expire.
* When we try to access a resource from endpoint B with an expired access token, we get a response status code of 401.
* We can then receive a new access (and refresh) token by sending a request to endpoint A.

### Defining the Authentication Service

At first, we want to define the authentication service. Usually, you will need to send a login request initially to obtain an access and a refresh token. However, to simplify this guide, we assume that we have these tokens already stored in our keychain.

To interact with the keychain, we use some (thread-safe and caching) instance that conforms to the following protocol (note that this protocol does not handle errors - again, to simplify this guide):

```swift
protocol KeychainService {

    func store<K>(_ value: K, for key: String) where K: Encodable
    func load<K>(_ type: K.Type, for key: String) -> K where K: Decodable
}
```

Given that protocol, we can define our authentication service:

```swift
struct MyAuthApi {

    private let keychain: KeychainService

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    var accessToken: String {
        get {
            keychain.load(String.self, for: "access_token")
        } set {
            keychain.store(newValue, for: "access_token")
        }
    }

    var refreshToken: String {
        get {
            keychain.load(String.self, for: "refresh_token")
        } set {
            keychain.store(newValue, for: "refresh_token")
        }
    }
}

extension MyAuthApi: HttpService {

    var apiUrl: String {
        "auth.borchero.com"
    }
}
```

Note that this definition of a service is very similar to before - we only added a few properties that are associated with the authentication service.

### Defining a Protected API

Using our authentication service, we can define the API which needs to provide access tokens to access protected resources.
All requests scheduled against this API need to provide a valid HTTP `Authorization` header, therefore, our API definition can set this automatically:

```swift
struct MyProtectedApi {

    private let auth: MyAuthApi

    init(auth: MyAuthApi) {
        self.auth = auth
    }
}

extension MyProtectedApi: HttpService {

    var apiUrl: String {
        "squid.borchero.com"
    }

    var header: HttpHeader {
        [.authorization: "Bearer \(auth.accessToken)"]
    }
}
```

### Defining the Retrier

Finally, we want to retry requests scheduled against `MyProtectedApi` whenever we receive a 401 HTTP status code as response. Before retrying, however, we need to schedule a request against `MyAuthApi` to refresh our token.

Therefore, we first want to define our request for refreshing tokens:

```swift
struct TokenRequestResponse: Decodable {

    let accessToken: String
    let refreshToken: String
}

struct TokenRequest: JsonRequest {

    typealias Result = TokenRequestResponse

    let refreshToken: String

    var method: HttpMethod {
        .post
    }

    var routes: HttpRoute {
        ["token"]
    }

    var body: HttpBody {
        HttpData.Json(["refresh_token": refreshToken])
    }
}
```

Here, we send the refresh token as JSON object to the server (usually, you would include some more information here) and we expect to receive an access as well as a refresh token.

At this point, it is possible to define our retrier (note that you will need to import `Combine` for this):

```swift
class AuthorizationRetrier: Retrier {

    private let auth: MyAuthApi
    private var cancellable: Cancellable?

    init(auth: MyAuthApi) {
        self.auth = auth
    }

    func retry<R>(_ request: R, failingWith error: Squid.Error) -> Future<Bool, Never> where R: Request {
        return Future { promise in
            switch error {
            case .requestFailed(statusCode: 401, response: _):
                // Here, we want to request a new token.
                let request = TokenRequest(refreshToken: self.auth.refreshToken)

                // Note that we do not need any synchronization primitives here as this retrier is used by a *single request*
                self.cancellable = request.schedule(with: self.auth).sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        // We don't need to do anything
                        break
                    case .failure(_):
                        // The request failed, we don't need to retry the original request
                        promise(.success(false))
                    }
                }) { value in
                    self.auth.accessToken = value.accessToken
                    self.auth.refreshToken = value.refreshToken

                    // The request finished successfully, retry the original request
                    promise(.success(true))
                }
            default:
                // Some other error occurred, we do not want to retry the request
                promise(.success(false))
            }
        }
    }
}
```

### Attaching the Retrier to the API

Now that we defined our retrier, we need to attach it to `MyProtectedApi` to actually use it for requests scheduled against it. We can easily do this as follows:

```swift
extension MyProtectedApi {

    var retrierFactory: RetrierFactory {
        return AnyRetrierFactory {
            return AuthorizationRetrier(auth: self.auth)
        }
    }
}
```

We need to provide a factory function here to ensure that a new instance of the retrier is used for each request.

### Final Notes

You might think that defining this retrier was a lot of work. However, you probably realized that retriers can be very powerful. Further, all requests that you schedule against `MyProtectedApi` can be scheduled equally well against an API that is not protected. That means that you can switch between APIs (e.g. for staging and production) hardly changing any of your code.
