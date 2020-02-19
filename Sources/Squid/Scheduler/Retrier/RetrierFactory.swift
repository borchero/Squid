//
//  RetrierFactory.swift
//  Squid
//
//  Created by Oliver Borchert on 9/22/19.
//

import Foundation

/// A retrier factory is a simple class that creates retriers for failed requests on demand. The
/// reason for using the factory is to allow for stateful retriers. As they cannot easily be shared
/// across requests, each request requires its own instance of the retrier. Consequently, any entity
/// implementing the `HttpService` protocol needs to provide a retrier factory yielding retriers
/// instead of a retrier instance.
///
/// When using your own retriers, you will most likely use the same retrier no matter the request.
/// In this case, you do not have to define a type implementing this protocol, but have a look at
/// `AnyRetrierFactory` instead.
public protocol RetrierFactory {

    /// Returns some retrier for the given request. This method is only called when the given
    /// request has failed. The factory may return different kinds of retriers for different
    /// requests. Whenever a retrier is stateful, it is also the responsibility of the factory
    /// to ensure that every invocation of this method returns a different instance of a retrier.
    ///
    /// - Parameter request: The request that has failed and for which to provide a retrier.
    func create<R>(for request: R) -> Retrier where R: Request
}
