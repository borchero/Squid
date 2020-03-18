# Pagination

When fetching large lists from a server, pagination is commonly used to fetch chunks of items one after the other.

Let's assume we are building a social networking application and want to fetch a user's followers from the server. Typically a user has several hundred followers, some may have a few million, so it isn't really necessary to fetch all of them.

## Defining the Types

Before we actually schedule the request and see how pagination works with Squid, we want to declare all required types, requests and services.

### Data Types

Our followers can be represented very easily. The server returns the name and a boolean whether the person is also following the user for which the request was sent. We define it as follows:

```swift
struct Follower: Decodable {

    let name: String
    let isFollowing: Bool
}
```

### Service

The API endpoint is simply characterized by an URL. For simplicity we don't employ anything such as retriers, hooks or the like.

```swift
struct OurgramApi: HttpService {

    var apiUrl: UrlConvertible {
        "ourgram.com"
    }
}
```

### Request

Arriving at defining the request itself, the interesting part begins. In many APIs, it can be observed that a pagination request does not differ from a regular request except for adding some metadata. That metadata is included in the request (e.g. the page and the number of items) and usually also returned by the server.

Hence, we can define the request to retrieve a user's followers very easily:

```swift
struct FollowerRequest: Request {

    typealias Result = [Follower]

    let userId: UUID

    var routes: HttpRoute {
        ["\(self.userId)", "followers"]
    }
}
```

As you can see, it is not yet required that the server actually performs pagination. You did not define anywhere that the request is paginated yet.

*Note: If your pagination API differs significantly from that format, you might need to include additional properties in the request such as the page number, the number of items, etc. Afterwards, you can schedule the request like any other.*

**Attention: Do not use such an API in the production environment. The client should never use a query parameter to "impersonate" a user. Use e.g. JWT tokens to identify clients that are properly logged in.**

## Scheduling the Request

Having defined all required types, we can now schedule the request against our API. When using Squid's pagination feature, you get some things for free, yet you get locked in a particular best-practice design of your API. Again, if you do not want that, you can implement pagination yourself by scheduling simple requests.

Essentially, Squid provides the following:

* When sending a request for pagination, two query parameters are automatically added: the page being requested (either zero-based or one-based) and the number of items being requested. So your original request gets modified as follows: `<url>?<parameters>` -> `<url>?<parameters>&page=xxx&chunk=yyy`. This format can *not* be changed.
* When receiving the result, you usually get some metadata delivered along with your actual data. For this, Squid provides the `PaginationContainer` type that you can use. Although it provides a lot of useful metadata along with the actual data, your API might return different information, possibly using different names. In this case, you can build your own "wrapping" container. Such a container must implement the `PaginatedData` protocol.

### Initializing a "Paginator"

When performing pagination, you usually have some kind of "state". This state usually represents the latest page that you requested and is initialized with the first page. For this, Squid provides the `Paginator` class. You cannot initialize it yourself, but you get an instance of it when you schedule your request for pagination.

When scheduling the request for pagination, you have to define how many items you want to have delivered per page and also the type that is returned by your server (for representing metadata). Optionally, you can also set whether the first page is indexed with 0 (by default, it's indexed with 1):

```swift
let service = OurgramApi()
let request = FollowerRequest(userId: UUID())

let paginator = request.schedule(forPaginationWith: service, chunk: 20, paginatedType: PaginationContainer.self)
```

### Receiving Data

Up to this point, no request has been sent to the server. Squid uses the paginator to transparently request successive pages. In order to do that, you simply provide a publisher that provides "ticks". Upon each tick, the next page is requested. To see exactly how many concurrent ticks or failures are handled, read the documentation for the `Paginator.connect(with:)` method.

A common use case is that you want to issue a request for a new page when you reach the bottom of a table view. For this, you can e.g. create a publisher that publishes every time your last cell is visible on screen. We call this publisher `tableViewTicks`.

When connecting this publisher to the paginator, the request for the first page is made immediately. This way, you do not have to issue a "dummy" tick once the table view becomes visible. Every subsequent request requires a tick:

```swift
let cancellable = paginator.connect(with: tableViewTicks)
    .sink(receiveCompletion: { completion in 
        // Handle request failure or end of list
    }, receiveValue: { users in
        // Append users to table view
    })
```

As you can deduce from the variable naming in the `receiveValue` closure, the actual users are returned. The `PaginationContainer` that was defined earlier is used *transparently* and never appears in any responses delivered by the server.
