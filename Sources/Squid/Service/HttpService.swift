//
//  Service.swift
//  Squid
//
//  Created by Oliver Borchert on 9/18/19.
//

import Foundation
import Combine

/// An HTTP service can be used to abstract a specific endpoint away from specific requests.
/// Usually, you would have one HTTP service per API that you use and possibly different services
/// for testing/staging and production. Intuitively, a specific implementation of an HTTP service
/// represents a particular API.
public protocol HttpService {

    // MARK: API Configuration
    /// The URL of the API representes by this HTTP service (e.g. "api.example.com"). This is the
    /// only field that needs to be provided by a particular implementation. This url should not
    /// contain the scheme (e.g. "https://") as it might get overwritten unexpectedly by a request.
    var apiUrl: UrlConvertible { get }

    /// A header that ought to be used by all requests issued against the API represented by this
    /// HTTP service. Most commonly, this header contains fields such as the API key or some form
    /// of Authorization. Request headers always overwrite header fields set by the HTTP service
    /// they are used with.
    var header: HttpHeader { get }

    /// A header that is provided asynchronously. If possible, use the `header` property instead.
    /// Implementing this property might be useful if some third-party component is used to e.g.
    /// fetch access tokens asynchronously. It will overwrite any values set in the `header`
    /// property if keys conflict.
    var asyncHeader: Future<HttpHeader, Error> { get }

    // MARK: Low-Level Configuration
    /// The session configuration to use for all requests using this service.
    var sessionConfiguration: URLSessionConfiguration { get }

    // MARK: Error Handling
    /// The retrier factory provides retriers for requests.
    ///
    /// - Note: When scheduling a `StreamRequest`, retriers will be ignored.
    var retrierFactory: RetrierFactory { get }

    // MARK: Hooks
    /// The hook describes a component that is called whenever a request is scheduled for this
    /// service and a result was obtained for a request. If an error occurs during scheduling,
    /// an error is indicated.
    ///
    /// - Note: When scheduling a `StreamRequest`, only the `onFailure` of the hook will be called
    ///         when an error occurs.
    var hook: ServiceHook { get }
}

extension HttpService {

    /// By default, the HTTP service does not set any headers.
    public var header: HttpHeader {
        return [:]
    }

    // By default, an empty publisher is returned which is equal to having a an empty async header.
    public var asyncHeader: Future<HttpHeader, Error> {
        return Future { promise in promise(.success([:])) }
    }

    /// By default, `URLSessionConfiguration.default` is used.
    public var sessionConfiguration: URLSessionConfiguration {
        return .default
    }

    /// By default, the default factory of the stateless `NilRetrier` is used, i.e. requests are
    /// never retried.
    public var retrierFactory: RetrierFactory {
        return NilRetrier.factory()
    }

    /// By default, a hook that does nothing is used.
    public var hook: ServiceHook {
        return NilServiceHook()
    }
}
