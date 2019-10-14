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
    
    /// Retries the given request that failed with the given error. Based on this information,
    /// the retrier is expected to perform any action such that the probability of the request
    /// succeeding when scheduled for the next time is increased. The function returns a future
    /// that should emit an boolean whether to actually retry the given request. When the emitted
    /// value is `true`, the request is retried immediately, otherwise, the upstream failure is
    /// propagated to the downstream subscriber immediately. As indicated by the types, the future
    /// may never fail.
    ///
    /// - Parameter request: The request that caused an error.
    /// - Parameter error: The error indiciating the reason for the failure of the request.
    mutating func retry<R>(_ request: R, failingWith error: Squid.Error) -> Future<Bool, Never>
        where R: Request
}

/// A stateless retrier is a retrier which does not need to track any state across retries. This
/// implies that the stateless retrier does **not** allow multiple retries. As it is stateless, it
/// must be initializable with no parameters. The advantage is that a factory can easily be derived.
public protocol StatelessRetrier: Retrier {
    
    /// Initializes the stateless retrier. Most of the time, this method will probably be empty.
    init()
}

extension StatelessRetrier {
    
    // MARK: Static Methods
    /// Creates a factory for the retrier class it is called on. The factory simply uses the empty
    /// initializer to yield instances of the class.
    public static func factory() -> some RetrierFactory {
        return StatelessRetrierFactory { return Self.init() }
    }
}
