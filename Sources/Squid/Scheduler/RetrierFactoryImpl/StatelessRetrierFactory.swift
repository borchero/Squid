//
//  StatelessRetrierFactory.swift
//  Squid
//
//  Created by Oliver Borchert on 9/22/19.
//

import Foundation

internal struct StatelessRetrierFactory: RetrierFactory {
    
    private let _create: () -> Retrier
    
    init(_ create: @escaping () -> Retrier) {
        self._create = create
    }
    
    func create<R>(for request: R) -> Retrier where R: Request {
        return self._create()
    }
}
