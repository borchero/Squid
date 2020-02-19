//
//  AnyRetrierFactory.swift
//  Squid
//
//  Created by Oliver Borchert on 9/22/19.
//

import Foundation

/// This entity may be used to provide retriers independent of the request that has been scheduled.
/// In most cases, this will be the only retrier factory that you are using.
public struct AnyRetrierFactory: RetrierFactory {

    private let _create: () -> Retrier

    /// Creates a new retrier factory by passing a closure that is simply executed when a new
    /// retrier is requested.
    ///
    /// - Parameter create: The method used to create new retriers. *Note that this closure must
    ///                     provide a new retrier per call.*
    public init(_ create: @escaping () -> Retrier) {
        self._create = create
    }

    public func create<R>(for request: R) -> Retrier where R: Request {
        return self._create()
    }
}
