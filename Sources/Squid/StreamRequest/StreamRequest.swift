//
//  Stream.swift
//  Squid
//
//  Created by Oliver Borchert on 10/5/19.
//

import Foundation

/// A request for a steram is similar to a `Request`, only that it does not send an HTTP request,
/// but asks for a web socket. Instead of a `Response` that yields at most one value, it therefore
/// returns a `Stream` which allows for receiving arbitrarily many values as well as sending values.
/// Apart from that, working with a stream request is very similar to working with an HTTP request.
/// It is also scheduled against an API represented by an `HttpService`. However, the service's
/// retriers as well as its headers are ignored. Still, the `Service.process(_:)` method is called.
public protocol StreamRequest: NetworkRequest {

    // MARK: Types
    /// Defines the type of the values sent by the client to the peer. By default, this is set to
    /// `Void`, indicating unidirectional communication from the peer to the client.
    associatedtype Message = Void
    
    /// Defines the type of the values sent from the peer to the client.
    associatedtype Result
    
    // MARK: Encoding Data for Sending
    /// Encodes a message sent from the client to the peer into an appropriate format for WebSocket
    /// communication. There exist default implementations for the case where `Message` is of type
    /// `Void`, `Data`, or `String`. In the first case, an error is thrown (as `Void` indicates
    /// unidirectional communication from the peer to the client). In the latter two cases, the
    /// returned value can be synthesized trivially.
    ///
    /// - Parameter message: The message to be sent from the client to the peer.
    func encode(_ message: Message) throws -> URLSessionWebSocketTask.Message
    
    // MARK: Decoding Data for Receiving
    /// Decodes a message sent by the peer into the stream's result type. There exist default
    /// implementations for result types `Void`, `Data` and `String`. In the former case, a `Void`
    /// value is returned no matter the message, in the latter two cases, the return value can be
    /// synthesized easily.
    ///
    /// - Parameter message: The message sent by the peer.
    func decode(_ message: URLSessionWebSocketTask.Message) throws -> Result
}

extension StreamRequest {
    
    // MARK: Establishing Streams
    /// Schedules the stream request against the API specified by the given HTTP service. The
    /// returned value is the stream over which messages can be sent (bidirectionally). Note that
    /// this method is very similar to `Request.schedule(with:)`.
    ///
    /// - Parameter service: The service representing the API against which to schedule this
    ///                      request.
    public func schedule(with service: HttpService) -> Stream<Self> {
        return NetworkScheduler.shared.schedule(self, service: service)
    }
}

extension StreamRequest where Message == Void {
    
    public func encode(_ message: Message) throws -> URLSessionWebSocketTask.Message {
        throw Squid.Error.encodingFailed
    }
}

extension StreamRequest where Message == Data {
    
    public func encode(_ message: Message) throws -> URLSessionWebSocketTask.Message {
        return .data(message)
    }
}

extension StreamRequest where Message == String {
    
    public func encode(_ message: Message) throws -> URLSessionWebSocketTask.Message {
        return .string(message)
    }
}

extension StreamRequest where Result == Void {
    
    public func decode(_ message: URLSessionWebSocketTask.Message) throws -> Result {
        return ()
    }
}

extension StreamRequest where Result == Data {
    
    public func decode(_ message: URLSessionWebSocketTask.Message) throws -> Result {
        switch message {
        case .data(let data):
            return data
        case .string:
            fallthrough
        @unknown default:
            throw Squid.Error.invalidResponse
        }
    }
}

extension StreamRequest where Result == String {
    
    public func decode(_ message: URLSessionWebSocketTask.Message) throws -> Result {
        switch message {
        case .string(let string):
            return string
        case .data:
            fallthrough
        @unknown default:
            throw Squid.Error.invalidResponse
        }
    }
}
