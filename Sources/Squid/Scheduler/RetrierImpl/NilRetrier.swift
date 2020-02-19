//
//  NilRetrier.swift
//  Squid
//
//  Created by Oliver Borchert on 9/19/19.
//

import Foundation
import Combine

/// This retrier is used to indicate that the request is not retried under any circumstances.
/// Upon calling the `retry` method, the returned Future immediately delivers a message that the
/// request does not need to be retried.
public struct NilRetrier: Retrier {

    /// Initializes a new factory yielding instances of nil retriers for requests (i.e. requests are
    /// never retried).
    public static func factory() -> RetrierFactory {
        // As this retrier is essentially empty, we do not need to initialize a new one for every
        // creation call.
        let retrier = NilRetrier()
        return AnyRetrierFactory { return retrier }
    }

    // MARK: Initialization
    /// Initializes a new never-retrying retrier. The implementation does nothing.
    public init() { }

    // MARK: Retrier
    public func retry<R>(_ request: R, failingWith error: Squid.Error) -> Future<Bool, Never>
    where R: Request {
        return Future { promise in
            promise(.success(false))
        }
    }
}
