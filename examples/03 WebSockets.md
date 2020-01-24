# WebSockets

Nowadays, [WebSockets](https://en.wikipedia.org/wiki/WebSocket) are the de facto standard for enabling bidirectional communication between client and server.
In fact, establishing a WebSocket is very similar to sending a normal HTTP request. The first request being sent is always a simple GET request which then gets *upgraded* to a WebSocket (WS) connection.
Despite the apparent similarity of sending requests to HTTP and WS endpoints, programmers on iOS are usually forced to use two entirely different libraries for HTTP and WS requests.

Squid solves this issue by providing an interface for WebSocket communication that aims to be as consistent as possible with its normal HTTP requests.

## Setting Up a Service

Just as for a normal HTTP request, you need to define a `HttpService` which must be used to schedule a WebSocket request:

```swift
struct MyApi: HttpService {

    var apiUrl: UrlConvertible {
        "echo.websocket.org"
    }
}
```

Note that you do not need to explicitly provide the protocol (e.g. `wss://`) as this will be inferred automatically when scheduling a request. As a result, you can use the same service for sending HTTP requests as well as WebSocket requests.

## Creating a Request for a WebSocket

As pointed out earlier, sending a request for a WebSocket is very similar to sending an HTTP request. As the request is, however, constrained to be a GET request, fewer parameters are available for specifying the request.

In practice, we conform to the `StreamRequest` protocol when specifying a request for a WebSocket. Since a WebSocket enables bidirectional communication, however, we not only need to define the type of the server's messages but also the type of the client messages.

For this guide, we will simply choose client and server messages to be of type `String` as then, we do not need to provide any custom encoding or decoding functions. Note that these functions are also implemented automatically when using the `JsonStreamRequest` protocol (similarly to the `JsonRequest` protocol for normal HTTP requests).

Nonetheless, the echo server that we are contacting in this guide only requires a very simply stream request:

```swift
struct EchoRequest: StreamRequest {

    typealias Message = String
    typealias Result = String
}
```

## Scheduling a Request for a WebSocket

Finally, you want to establish a connection. This is hardly any different from sending a request as it is simply scheduled against an API:

```swift
let service = MyApi()
let request = EchoRequest()
let stream = request.schedule(with: service)
```

In contrast to a normal HTTP request, however, the returned value is a `Stream` and behaves a bit differently.

Once subscribed to the stream, the connection is initiated and the stream emits messages sent by the server. Likewise, messages can be sent to the server. Note that messages are queued (in no particular order) if messages are sent before anyone has subscribed. They are sent simultaneously as soon as the stream exists.

When there are multiple subscribers, they receive values from the same stream. Be aware that messages sent over the stream are *not* buffered but delivered as they arrive.

## Listening for Messages

When listening to messages, we need to understand the `Stream` publisher. The stream emits `Result` objects that either deliver the actual result (`String` in our case) or an error if receiving the message fails for some reason (e.g. message cannot be decoded). The stream only errors out when the WebSocket connection fails entirely.

Therefore, we subscribe to the stream as follows:

```swift
let c = stream.sink(receiveCompletion: { completion in
    switch completion {
    case .failure(let error):
        print("WebSocket was closed with error: \(error)")
    case .finished:
        print("WebSocket was closed without error.")
    }
}) { result in
    switch result {
    case .success(let message):
        print("Received message: \(message)")
    case .failure(let error):
        print("Receiving message failed due to: \(error)")
    }
}
```

## Sending Messages

While the stream is active, messages can be sent over the stream. The result is a publisher that publishes exactly once and never fails. As, however, sending the message might fail, the response is a `Result` object. We can therefore send a message as follows:

```swift
let s = stream.send("Hello Stream!").sink { result in
    switch result {
    case .success(_):
        print("Sending the message succeeded.")
    case .failure(let error):
        print("Sending the message failed due to: \(error)")
    }
}
```

In our case, the subscriber will then receive the sent value by the echo server.

*Note that, at the moment, sending from multiple threads simultaneously is not guaranteed to work as Apple does not yet provide sufficient documentation for its new WebSocket API inside `URLSession`.*
