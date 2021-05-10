//
//  Request.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation
import Combine

/// The request protocol is the core building block of the Squid framework. The general idea of a
/// request is that it declaratively defines the content of an HTTP request. It is then *scheduled*
/// against an API that is represented by a `HttpService`. Scheduling the request returns a
/// `Response`. This response is a shared publisher that can be subscribed to.
///
/// The reason for abstracting requests away from APIs, i.e. HTTP services, is that often, requests
/// are issued against differing domains with differing security requirements during testing/staging
/// and development. Hence, it makes sense to capture methods, routing paths, headers, etc. in the
/// request itself but abstract away the actual URL and common API headers into the `HttpService`.
public protocol Request: NetworkRequest {

    // MARK: Types
    /// The expected type of the server's response upon a successful request.
    associatedtype Result

    // MARK: Request Specification
    /// The HTTP method of the request.
    var method: HttpMethod { get }

    /// The HTTP body of the request. May only be set to an instance of something other than
    /// `HttpData.Empty` if `method` is set to PUT or GET. By default, an instance of
    /// `HttpData.Empty` is returned.
    var body: HttpBody { get }

    /// Prepares the URL request that will be sent. The function is passed the request as assembled
    /// based on all other properties. You may modify the request as you wish.
    ///
    /// - Note: This function should only be used if it is not possible to specify the request in a
    ///         fully declarative form.
    /// - Attention: For performance reasons, you should not modify the request's body at the
    ///              moment. When you modify it and debug statements are printed, the old body may
    ///              be printed although this is not the body being sent.
    ///
    /// - Parameter request: The request, pre-populated with all properties specified in the
    ///                      request.
    func prepare(_ request: URLRequest) -> URLRequest

    // MARK: Expected Response
    /// The range of accepted status codes for the request. Whenever the response's status code is
    /// not in the provided range, the request is considered to have failed.
    var acceptedStatusCodes: CountableClosedRange<Int> { get }

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
    /// In addition, it has a default implementation if the return type is `String`. The data is
    /// expected to be encoded with UTF-8.
    ///
    /// - Parameter data: The raw data returned by the raw HTTP response.
    func decode(_ data: Data) throws -> Result
}

extension Request {

    /// Defaults to GET.
    public var method: HttpMethod {
        return .get
    }

    /// Defaults to an empty body.
    public var body: HttpBody {
        return HttpData.Empty()
    }

    /// The default implementation returns the request without any modifications.
    public func prepare(_ request: URLRequest) -> URLRequest {
        return request
    }

    /// By default, all 2xx status codes are accepted.
    public var acceptedStatusCodes: CountableClosedRange<Int> {
        return 200...299
    }

    // MARK: Scheduling Requests
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
    public func schedule<S>(with service: S) -> Response<Self, S> where S: HttpService {
        return NetworkScheduler.shared.schedule(self, service: service)
    }

    /// Schedules the request as paginated request against the API specified by the given HTTP
    /// service. The response is a `PaginationResponse`. Consult its documentation to know how to
    /// work with a paginated request.
    ///
    /// - Parameter service: The service representing the API against which to schedule paginated
    ///                      requests.
    /// - Parameter chunk: The (maximum) number of elements that are requested per page. The number
    ///                    of returned elements is only smaller than the given chunk if the given
    ///                    page index is the index of the last page and the number of elements is
    ///                    not divisible by the chunk.
    /// - Parameter zeroBasedPageIndex: Whether the API endpoint that the request is scheduled
    ///                                 against indexes the first page with 0. By default, the first
    ///                                 page is indexed by 1.
    /// - Parameter decode: A closure that is used to decode the received data to the defined type
    ///                     of `PaginatedData`. The closure receives both the body and the request
    ///                     as the original `Request.decode(_:)` method might want to be used.
    public func schedule<P, S>(
        forPaginationWith service: S, chunk: Int, zeroBasedPageIndex: Bool = false,
        decode: @escaping (Data, Self) throws -> P
    ) -> Paginator<Self, P, S> where P: PaginatedData, P.DataType == Result, S: HttpService {
        return Paginator(
            base: self, service: service, chunk: chunk,
            zeroBasedPageIndex: zeroBasedPageIndex, decode: decode
        )
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

extension Request where Result == String {

    public func decode(_ data: Data) throws -> Result {
        guard let string = String(data: data, encoding: .utf8) else {
            throw Squid.Error.decodingFailed
        }
        return string
    }
}

extension Request {

    internal func validate() -> Squid.Error? {
        if (self.method == .get || self.method == .delete) && !(self.body is HttpData.Empty) {
            return .invalidRequest(
                message: "Request must not have HTTP method GET/DELETE and a non-empty body."
            )
        }
        return nil
    }
}

// MARK: JSON
/// This request protocol is a specialization of the `Request` protocol. It can be used often when
/// working with a JSON API where the returned data is a JSON object. As a requirement, the
/// request's result type must implement the `Decodable` protocol. The `decode(_:)` method is then
/// synthesized automatically by using a `JSONDecoder` and decoding the raw data to the specified
/// type.
public protocol JsonRequest: Request where Result: Decodable { }

extension JsonRequest {

    public func decode(_ data: Data) throws -> Result {
        let decoder = SquidCoders.shared.decoder
        return try decoder.decode(Result.self, from: data)
    }
}

extension JsonRequest {

    /// This method is very similar to the method
    /// `Request.schedule(forPaginationWith:chunk:zeroBasedPageIndex:decode:)`, however, the user
    /// does not have to explicitly define a `decode` function whenever both the actual result and
    /// the type of `PaginatedData` to be used conform to the `Decodable` protocol. The type of the
    /// paginated data is tried to be inferred automatically, but might need to be given explicitly
    /// in some circumstances.
    ///
    /// - Parameter service: The service representing the API against which to schedule paginated
    ///                      requests.
    /// - Parameter chunk: The (maximum) number of elements that are requested per page. The number
    ///                    of returned elements is only smaller than the given chunk if the given
    ///                    page index is the index of the last page and the number of elements is
    ///                    not divisible by the chunk.
    /// - Parameter zeroBasedPageIndex: Whether the API endpoint that the request is scheduled
    ///                                 against indexes the first page with 0. By default, the first
    ///                                 page is indexed by 1.
    /// - Parameter paginatedType: The paginated data type to which to decode a response.
    public func schedule<P, S>(forPaginationWith service: S, chunk: Int,
                               zeroBasedPageIndex: Bool = false,
                               paginatedType: P.Type = P.self) -> Paginator<Self, P, S>
    where P: PaginatedData, P.DataType == Result, P: Decodable, S: HttpService {
        return Paginator(
            base: self, service: service, chunk: chunk, zeroBasedPageIndex: zeroBasedPageIndex
        ) { data, _ -> P in
            let decoder = SquidCoders.shared.decoder
            return try decoder.decode(P.self, from: data)
        }
    }
}

// MARK: Internal
extension Request {

    internal func responsePublisher<S>(
        service: S, session: URLSession, subject: CurrentValueSubject<URLRequest?, Never>,
        requestId: Int
    ) -> AnyPublisher<RawHttpResponse, Squid.Error> where S: HttpService {
        let httpRequest = HttpRequest
            .publisher(for: self, service: service)
            .handleEvents(receiveOutput: { subject.send($0.urlRequest) })

        #if DEBUG
        let response = httpRequest
            .debug(request: self, requestId: requestId)
            .flatMap { HttpTaskPublisher(request: $0.urlRequest, in: session) }
            .debug(request: self, requestId: requestId)
        #else
        let response = httpRequest
            .flatMap { HttpTaskPublisher(request: $0.urlRequest, in: session) }
        #endif

        return response
            .validate(statusCodeIn: self.acceptedStatusCodes)
            .eraseToAnyPublisher()
    }

    internal func retriedResponsePublisher<S>(
        service: S, session: URLSession, retrier: Retrier,
        subject: CurrentValueSubject<URLRequest?, Never>, requestId: Int
    ) -> AnyPublisher<RawHttpResponse, Squid.Error> where S: HttpService {
        let response = self.responsePublisher(
            service: service, session: session, subject: subject, requestId: requestId
        )

        return response
            .catch { error -> AnyPublisher<RawHttpResponse, Squid.Error> in
                retrier
                    .retry(self, failingWith: error)
                    .setFailureType(to: Squid.Error.self)
                    .flatMap { retry -> AnyPublisher<RawHttpResponse, Squid.Error> in
                        switch (retry, retrier.allowsMultipleRetries) {
                        case (true, true):
                            return self.retriedResponsePublisher(
                                service: service, session: session, retrier: retrier,
                                subject: subject, requestId: requestId
                            )
                        case (true, false):
                            return self.responsePublisher(
                                service: service, session: session, subject: subject,
                                requestId: requestId
                            )
                        case (false, _):
                            return Fail(error: error).eraseToAnyPublisher()
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
}

extension Publisher where Output == RawHttpResponse {

    func validate(
        statusCodeIn range: CountableClosedRange<Int>
    ) -> AnyPublisher<Output, Squid.Error> {
        return self.tryMap { response -> Output in
            let statusCode = response.base.statusCode
            if !range.contains(statusCode) {
                throw Squid.Error.requestFailed(statusCode: statusCode, response: response.body)
            }
            return response
        }.mapError(Squid.Error.ensure)
        .eraseToAnyPublisher()
    }
}

extension Publisher where Output == HttpRequest {

    func debug<R>(
        request: R, requestId: Int
    ) -> Publishers.HandleEvents<Self> where R: NetworkRequest {
        return self.handleEvents(receiveOutput: { httpRequest in
            Squid.Logger.shared.log(
                "Scheduled request `\(type(of: request))` with identifier \(requestId):\n" +
                httpRequest.description.indent(spaces: 4)
            )
        })
    }
}
