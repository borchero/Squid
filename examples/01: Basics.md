# Squid Basics

At its very core, Squid establishes two main entities that are used for making network requests:

* **Services** abstract API endpoints. They define an endpoint (i.e. a base URL, e.g. `places.google.com`), common HTTP headers that e.g. need to be used by all requests to authenticate against the API, and more (have a look at the `HttpService` protocol for a comprehensive overview).
* **Requests** are *scheduled* using a service and therefore provide only request-specific information. This includes e.g. the HTTP Method, routing paths, query parameters, or the HTTP body. Further, they define an expected result type that ought to be returned by the server. In case of JSON responses, Squid automatically tries to decode the response to the specified type.

## Defining Services

Defining a specific service is very straightforward. You only have to conform to the `HttpService` protocol and implement its sole required property, the URL of the API:

```swift
struct MyApi: HttpService {

    var apiUrl: UrlConvertible {
        "https://jsonplaceholder.typicode.com"
    }
}
```

## Defining HTTP Requests

Again, defining an HTTP request is very straightforward. A request simply needs to conform to the `Request` protocol and implement its required methods. In fact, the only required method is the `decode(_:)` method where the `Data` returned by the server is transformed into the request's result type.

Commonly, however, you will want to talk to a JSON API and therefore, you may also conform to the `JsonRequest` protocol. Given that the request's result type is `Decodable`, the `decode(_:)` method has a useful default implementation.

For this guide, let us define the following `User` type:

```swift
struct User: Decodable {

    let id: Int
    let username: String
    let name: String
}
```

Using this type, we can now easily define a request that expects a list of such users:

```swift
struct UserRequest: JsonRequest {

    typealias Result = [User]

    var routes: HttpRoute {
        ["users"]
    }
}
```

Note that the `Request` protocol includes plenty of useful default implementations for various options that a request can have (e.g. HTTP method, headers, ...). Look at the protocol documentation to get an overview.

## Scheduling HTTP Requests

Having defined a request and a service, a request must be *scheduled*:

```swift
let service = MyApi()
let request = UserRequest()
let response = request.schedule(with: service)
```

The `response` variable is of type `Response` and is a Combine `Publisher` that can be subscribed to. Once subscribed for the first time, the request is actually sent and the result is delivered shortly (assuming that no error occurs).

When another subscriber subscribes to the same scheduled request, the request is *not* sent again, but the response is passed to the subscriber once available.

Note that when all subscriptions are cancelled, the request is also cancelled.

An example on how to use the response might be the following:

```swift
let c = response.sink(receiveCompletion: { completion in
    switch completion {
        case .failure(let error):
            print("Request failed due to: \(error).")
        case .finished:
            print("Request finished.")
    }
}) { users in
    print("Received users: \(users)")
}
```

However, the fact that the `response` variable is a simple `Publisher` enables a wide range of possibilities how to work with the returned response.
