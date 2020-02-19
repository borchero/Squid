//
//  AnyHttpService.swift
//  Squid
//
//  Created by Oliver Borchert on 9/18/19.
//

import Foundation

/// This entity provides a way to initialize an HTTP service without implementing the `HttpService`
/// protocol in a custom entity. Note that you should usually implement the `HttpService` protocol
/// instead of simply using an instance of `AnyHttpService`. This class is mainly used internally.
public struct AnyHttpService: HttpService {

    // MARK: Properties
    public let apiUrl: UrlConvertible
    public let header: HttpHeader
    public let sessionConfiguration: URLSessionConfiguration
    public let retrierFactory: RetrierFactory
    private let _process: (Squid.Error) -> Void

    // MARK: Initialization
    /// Initializes a new HTTP service while setting all parameters as provided.
    ///
    /// - Parameter url: The URL of the API represented by the HTTP service.
    /// - Parameter header: The header fields shared among all requests. Defaults to no fields.
    /// - Parameter sessionConfiguration: The session configuration to use for all requests.
    ///                                   Defaults to `URLSessionConfiguration.default`.
    /// - Parameter retrierFactory: An instance of a retrier factory to generate retriers from.
    /// - Parameter processError: A closure to execute on request errors.
    public init(at url: UrlConvertible,
                header: HttpHeader = [:],
                sessionConfiguration: URLSessionConfiguration = .default,
                retrierFactory: RetrierFactory = NilRetrier.factory(),
                processError: @escaping (Squid.Error) -> Void = { _ in }) {
        self.apiUrl = url
        self.header = header
        self.sessionConfiguration = sessionConfiguration
        self.retrierFactory = retrierFactory
        self._process = processError
    }

    // MARK: Instance Methods
    public func process(_ error: Squid.Error) {
        self._process(error)
    }
}
