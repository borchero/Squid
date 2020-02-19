//
//  NonCachingFuture.swift
//  Squid
//
//  Created by Oliver Borchert on 2/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import Combine

internal struct UnsharedFuture<Output, Failure>: Publisher where Failure: Error {

    typealias Promise = (Result<Output, Failure>) -> Void

    private let promise: (@escaping Promise) -> Void

    public init(_ attemptToFulfill: @escaping (@escaping Promise) -> Void) {
        self.promise = attemptToFulfill
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = FutureSubscription(subscriber: subscriber, promise: self.promise)
        subscriber.receive(subscription: subscription)
    }
}

private class FutureSubscription<S>: Subscription where S: Subscriber {

    typealias Promise = (Result<S.Input, S.Failure>) -> Void

    private var subscriber: S?
    private let promise: (@escaping Promise) -> Void

    init(subscriber: S, promise: @escaping (@escaping Promise) -> Void) {
        self.subscriber = subscriber
        self.promise = promise
    }

    func request(_ demand: Subscribers.Demand) {
        guard demand > 0 else {
            return
        }
        self.promise { result in
            switch result {
            case .failure(let error):
                self.subscriber?.receive(completion: .failure(error))
            case .success(let value):
                _ = self.subscriber?.receive(value)
                self.subscriber?.receive(completion: .finished)
            }
        }
    }

    func cancel() {
        self.subscriber = nil
    }

    deinit {
        self.cancel()
    }
}
