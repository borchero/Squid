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
public struct NilRetrier: StatelessRetrier {
    
    // MARK: Initialization
    /// Initializes a new never-retrying retrier. The implementation does nothing.
    public init() { }
    
    // MARK: Retrier
    public func retry<R>(_ request: R, failingWith error: Squid.Error) -> Future<Bool, Never>
    where R : Request {
        return Future { promise in
            promise(.success(false))
        }
    }
}
