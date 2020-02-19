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
    /// HTTP requests, "wss" for WebSockets). By default, this is set to `true`. Think twice before
    /// setting this to `false` and allowing insecure network requests.
    var usesSecureProtocol: Bool { get }

    // MARK: URL Manipulation
    /// The routing paths of the request. By default, no routing paths are used.
    var routes: HttpRoute { get }

    /// The query parameters to be used in the request. Defaults to no parameters.
    var query: HttpQuery { get }

    /// The header fields set when scheduling the request. These fields overwrite potential header
    /// fields defined by the HTTP service that the request is issued against. Defaults to no
    /// headers.
    var header: HttpHeader { get }

    // MARK: Fine-Tuning
    /// The priority of the request. Defaults to `.userInitiated`.
    var priority: RequestPriority { get }
}

extension NetworkRequest {

    public var usesSecureProtocol: Bool {
        return true
    }

    public var routes: HttpRoute {
        return []
    }

    public var query: HttpQuery {
        return [:]
    }

    public var header: HttpHeader {
        return [:]
    }

    public var priority: RequestPriority {
        return .userInitiated
    }
}
