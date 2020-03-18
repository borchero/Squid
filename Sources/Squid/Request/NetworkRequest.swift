//
//  NetworkRequest.swift
//  Squid
//
//  Created by Oliver Borchert on 10/8/19.
//

import Foundation

/// The network request is a protocol that serves as a base protocol for requests on remote servers.
/// The protocol is mainly used as a common base for `Request` and `StreamRequest`. You should
/// never directly use this protocol as it hardly provides any functionality.
public protocol NetworkRequest {

    // MARK: Protocol
    /// Whether the request makes use of the secure counterpart of the protocol (e.g. "https" for
    /// HTTP requests, "wss" for WebSockets).
    var usesSecureProtocol: Bool { get }

    // MARK: URL Manipulation
    /// The routing paths of the request.
    var routes: HttpRoute { get }

    /// The query parameters to be used in the request.
    var query: HttpQuery { get }

    /// The header fields set when scheduling the request. These fields overwrite potential header
    /// fields defined by the HTTP service that the request is issued against.
    var header: HttpHeader { get }

    // MARK: Fine-Tuning
    /// The priority of the request.
    var priority: RequestPriority { get }

    /// The number of seconds to wait before a request is considered to have failed.
    var timeout: TimeInterval { get }
}

extension NetworkRequest {

    /// By default, this is set to `true`. Think twice before setting this to `false` and allowing
    /// insecure network requests.
    public var usesSecureProtocol: Bool {
        return true
    }

    /// By default, no routing paths are used.
    public var routes: HttpRoute {
        return []
    }

    /// Defaults to no parameters.
    public var query: HttpQuery {
        return [:]
    }

    /// Defaults to no headers.
    public var header: HttpHeader {
        return [:]
    }

    /// Defaults to `.userInitiated`.
    public var priority: RequestPriority {
        return .userInitiated
    }

    /// Defaults to `TimeInterval.infinity`, i.e. no timeout is ever raised.
    public var timeout: TimeInterval {
        return TimeInterval.infinity
    }
}
