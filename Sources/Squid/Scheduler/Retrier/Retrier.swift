//
//  StatelessRetrier.swift
//  Squid
//
//  Created by Oliver Borchert on 9/18/19.
//

import Foundation
import Combine

/// A retrier represents a "callback" that is executed whenever a request fails. One option for a
/// retrier is to retry a failed request only once. An example might be a retrier that refreshes
/// an authentication token when the server returns a 401 status code. Another option for the
/// retrier is to retry multiple times. A common example might be a retrier that "backs off"
/// exponentially long to ensure that a request is fulfilled at some time.
public protocol Retrier {

    /// Whether the retrier may retry requests for multiple times or if - when the request fails -
    /// the retrier is not called again. Defaults to `false`.
    var allowsMultipleRetries: Bool { get }

    /// Retries the given request that failed with the given error. Based on this information,
    /// the retrier is expected to perform any action such that the probability of the request
    /// succeeding when scheduled for the next time is increased. The function returns a future
    /// that should emit a boolean whether to actually retry the given request. When the emitted
    /// value is `true`, the request is retried immediately, otherwise, the upstream failure is
    /// propagated to the downstream subscriber immediately. As indicated by the types, the future
    /// may never fail.
    ///
    /// - Parameter request: The request that caused an error.
    /// - Parameter error: The error indiciating the reason for the failure of the request.
    func retry<R>(_ request: R, failingWith error: Squid.Error) -> Future<Bool, Never>
        where R: Request
}

extension Retrier {

    public var allowsMultipleRetries: Bool {
        return false
    }
}
