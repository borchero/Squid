//
//  AnyStreamRequest.swift
//  Squid
//
//  Created by Oliver Borchert on 10/8/19.
//

import Foundation

/// This struct can be used to construct stream requests easily without having to define a custom
/// entity conforming to the `StreamRequest` protocol and defining some `HttpService`. The specifics
/// of this entity are very similar to the specifics of `AnyRequest`. Note, however, that this
/// entity restricts messages being sent and received to be of type `String`.
public struct AnyStreamRequest: StreamRequest {

    // MARK: Types
    public typealias Message = String
    public typealias Result = String

    // MARK: Properties
    private let service: HttpService

    public let routes: HttpRoute
    public let query: HttpQuery
    public let priority: RequestPriority

    // MARK: Initialization
    /// Initializes a new stream request for a particular URL.
    ///
    /// - Parameter url: The URL of the request.
    /// - Parameter query: The request's query parameters. Defaults to no parameters.
    /// - Parameter priority: The priority of the request. Defaults to `.default`.
    public init(url: UrlConvertible,
                query: HttpQuery = [:],
                priority: RequestPriority = .default) {
        self.init(
            routes: [], query: query, priority: priority, service: AnyHttpService(at: url)
        )
    }

    /// Initializes a new stream request based on a predefined `HttpService`.
    ///
    /// - Parameter routes: The routing paths for the request. The final URL is constructed by
    ///                     making use of the given `service`.
    /// - Parameter query: The request's query parameters. Defaults to no parameters.
    /// - Parameter priority: The priority of the request. Defaults to `.default`.
    /// - Parameter service: The service representing an API.
    public init(routes: HttpRoute,
                query: HttpQuery = [:],
                priority: RequestPriority = .default,
                service: HttpService) {
        self.service = service
        self.routes = []
        self.query = query
        self.priority = priority
    }

    // MARK: Instance Methods
    /// Schedules the request and, as expected, returns a `Stream` publisher. As the service is
    /// transparently constructed when initializing the request, there is no need to pass a service
    /// in this case. This implies that the user should **not** use the `schedule(with:)` method.
    public func schedule() -> Stream<Self> {
        return self.schedule(with: self.service)
    }
}
