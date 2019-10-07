//
//  Request.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

/// The request protocol is the core building block of the Squid framework. The general idea of a
/// request is that it declaratively defines the content of an HTTP request. It is then *scheduled*
/// against an API that is represented by a `HttpService`. Scheduling the request returns a
/// `Response`. This response is a shared publisher that can be subscribed to.
///
/// The reason for abstracting requests away from APIs, i.e. HTTP services, is that often, requests
/// are issued against differing domains with differing security requirements during testing/staging
/// and development. Hence, it makes sense to capture methods, routing paths, headers, etc. in the
/// request itself but abstract away the actual URL and common API headers into the `HttpService`.
public protocol Request {
    
    /// The expected type of the server's response upon a successful request.
    associatedtype Result
    
    /// The routing paths of the request. By default, no routing paths are used.
    var routes: HttpRoute { get }
    
    /// The HTTP method of the request. Defaults to GET.
    var method: HttpMethod { get }
    
    /// The query parameters to be used in the request. Defaults to no parameters.
    var query: HttpQuery { get }
    
    /// The header fields set when scheduling the request. These fields overwrite potential header
    /// fields defined by the HTTP service that the request is issued against. Defaults to no
    /// headers.
    var header: HttpHeader { get }
    
    /// The HTTP body of the request. May only be set to an instance of something other than
    /// `HttpData.Empty` if `method` is set to PUT or GET. By default, an instance of
    /// `HttpData.Empty` is returned.
    var body: HttpBody { get }
    
    /// The range of accepted status codes for the request. Whenever the response's status code is
    /// not in the provided range, the request is considered to have failed. By default, all 2xx
    /// status codes are accepted.
    var acceptedStatusCodes: CountableClosedRange<Int> { get }
    
    /// The priority of the request. Defaults to `.userInitiated`.
    var priority: RequestPriority { get }
    
    /// Upon successful completion of the HTTP request itself, this method is responsible for
    /// transforming the raw `Data` returned by the HTTP response into the response's result type.
    /// If this method throws an exception, the request is also considered to have failed. As a
    /// result, retriers are called and the `Response` publisher returned upon scheduling the
    /// request will not yield any value.
    ///
    /// This method has a default implementation if the request's result type is either `Void` or
    /// `Data`. In the former case, this method does nothing and returns `Void`. In the latter case,
    /// it simply returns the data passed as parameter. As a result, in both cases, this method will
    /// never throw.
    ///
    /// - Parameter data: The raw data returned by the raw HTTP response.
    func decode(_ data: Data) throws -> Result
}

extension Request {
    
    public var routingPaths: [String] {
        return []
    }
    
    public var method: HttpMethod {
        return .get
    }
    
    public var query: HttpQuery {
        return [:]
    }
    
    public var header: HttpHeader {
        return [:]
    }
    
    public var body: HttpBody {
        return HttpData.Empty()
    }
    
    public var acceptedStatusCodes: CountableClosedRange<Int> {
        return 200...299
    }
    
    public var priority: RequestPriority {
        return .userInitiated
    }
    
    /// Schedules the request against the API specified by the given HTTP service. The response is
    /// a publisher that yields the request's result type upon success or an error upon failure.
    /// The `schedule` method is the only method that may be used to obtain responses for requests.
    /// When the application is compiled in `DEBUG` mode and `Squid.Logger` has not been silenced,
    /// the request also prints debugging statements to the console: firstly, the request itself
    /// is printed as soon as it is scheduled. Secondly, the response (or an error) is printed as
    /// soon as it has been returned. Printing in `RELEASE` mode is not possible as the respective
    /// print statements are not included in the binary.
    ///
    /// - Parameter service: The service representing the API against which to schedule this
    ///                      request.
    public func schedule(with service: HttpService) -> Response<Self> {
        return NetworkScheduler.shared.schedule(self, service: service)
    }
}

extension Request where Result == Data {
    
    public func decode(_ data: Data) throws -> Result {
        return data
    }
}

extension Request where Result == Void {
    
    public func decode(_ data: Data) throws -> Result {
        return ()
    }
}

/// This request protocol is a specialization of the `Request` protocol. It can be used often when
/// working with a JSON API where the returned data is a JSON object. As a requirement, the
/// request's result type must implement the `Decodable` protocol. The `decode(_:)` method is then
/// synthesized automatically by using a `JSONDecoder` and decoding the raw data to the specified
/// type. `decodeSnakeCase` can further be used to modify the behavior of the aforementioned
/// decoder.
public protocol JsonRequest: Request where Result: Decodable {
    
    /// Defines whether the decoder decoding the raw data to the result type should consider
    /// camel case in the Swift code as snake case in the JSON (i.e. `userID` would be parsed from
    /// the field `user_id` if not specified explicity in the type to decode to). By default,
    /// attributes are decoded using snake case attribute names.
    var decodeSnakeCase: Bool { get }
}

extension JsonRequest {
    
    public var decodeSnakeCase: Bool {
        return true
    }
    
    public func decode(_ data: Data) throws -> Result {
        let decoder = JSONDecoder()
        if self.decodeSnakeCase {
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        }
        return try decoder.decode(Result.self, from: data)
    }
}
