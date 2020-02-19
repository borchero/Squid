//
//  AnyRequest.swift
//  Squid
//
//  Created by Oliver Borchert on 9/18/19.
//

import Foundation

/// This struct can be used to construct requests easily without having to define a custom entity
/// conforming to the `Request` protocol and defining some `HttpService`. In a larger application,
/// you should refrain from using this struct, however, it might be useful in small projects and
/// when writing tests.
///
/// This request fixes the result type to `Data` such that the user can decode to the desired type
/// via calling the `decode(type:decoder:)` function on the returned `Response` publisher when
/// scheduling the request.
///
/// As this request struct abstracts away the `HttpService` in favor for a simpler interface,
/// scheduling can be performed even easier.
///
/// **Note that this entity does not allow to make insecure requests over HTTP (only HTTPS).**
public struct AnyRequest: Request {

    // MARK: Types
    public typealias Result = Data

    // MARK: Properties
    private let service: HttpService

    public let routes: HttpRoute

    public let method: HttpMethod
    public let query: HttpQuery
    public let header: HttpHeader
    public let body: HttpBody

    public let acceptedStatusCodes: CountableClosedRange<Int>
    public let priority: RequestPriority

    // MARK: Initialization
    /// Initializes a new request for a particular URL.
    ///
    /// - Parameter method: The HTTP method for the request. Defaults to GET.
    /// - Parameter url: The URL of the request.
    /// - Parameter query: The request's query parameters. Defaults to no parameters.
    /// - Parameter header: The request's headers. Defaults to no header fields.
    /// - Parameter body: The request's body. Defaults to an empty body.
    /// - Parameter acceptedStatusCodes: Acceptable status codes for a successful response. Defaults
    ///                                  to all 2xx status codes.
    /// - Parameter priority: The priority of the request. Defaults to `.default`.
    public init(_ method: HttpMethod = .get,
                url: UrlConvertible,
                query: HttpQuery = [:],
                header: HttpHeader = [:],
                body: HttpBody = HttpData.Empty(),
                acceptedStatusCodes: CountableClosedRange<Int> = 200...299,
                priority: RequestPriority = .default) {
        self.init(
            method, routes: [], query: query, header: header, body: body,
            acceptedStatusCodes: acceptedStatusCodes, priority: priority,
            service: AnyHttpService(at: url)
        )
    }

    /// Initializes a new request based on a predefined `HttpService`.
    ///
    /// - Parameter method: The HTTP method for the request. Defaults to GET.
    /// - Parameter routes: The routing paths for the request. The final URL is constructed by
    ///                     making use of the given `service`.
    /// - Parameter query: The request's query parameters. Defaults to no parameters.
    /// - Parameter header: The request's headers. Defaults to no header fields.
    /// - Parameter body: The request's body. Defaults to an empty body.
    /// - Parameter acceptedStatusCodes: Acceptable status codes for a successful response. Defaults
    ///                                  to all 2xx status codes.
    /// - Parameter priority: The priority of the request. Defaults to `.default`.
    /// - Parameter service: The service representing an API.
    public init(_ method: HttpMethod = .get,
                routes: HttpRoute,
                query: HttpQuery = [:],
                header: HttpHeader = [:],
                body: HttpBody = HttpData.Empty(),
                acceptedStatusCodes: CountableClosedRange<Int> = 200...299,
                priority: RequestPriority = .default,
                service: HttpService) {
        self.service = service
        self.routes = []
        self.method = method
        self.query = query
        self.header = header
        self.body = body
        self.acceptedStatusCodes = acceptedStatusCodes
        self.priority = priority
    }

    // MARK: Instance Methods
    /// Schedules the request and, as expected, returns a `Response` publisher. As the service is
    /// transparently constructed when initializing the request, there is no need to pass a service
    /// in this case. This implies that the user should **not** use the `schedule(with:)` method.
    public func schedule() -> Response<Self> {
        return self.schedule(with: self.service)
    }
}
