//
//  Replay.swift
//  Squid
//
//  Created by Oliver Borchert on 10/11/19.
//

import Foundation
import Combine

extension Publisher {

    internal func shareReplayLatest() -> AnyPublisher<Output, Failure> {
        let subject = CurrentValueSubject<Output?, Failure>(nil)
        return self.map(Optional.some)
            .multicast(subject: subject).autoconnect()
            .filter { $0 != nil }.map { $0! }
            .eraseToAnyPublisher()
    }
}
