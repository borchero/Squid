//
//  IgnoreError.swift
//  Squid
//
//  Created by Oliver Borchert on 10/10/19.
//

import Foundation
import Combine

extension Publisher {

    /// Use this function whenever you want to ignore all errors emitted by the upstream publisher.
    /// Note that this does *not* restore the upstream publisher if it fails but, instead, emits
    /// a completion message instead of the error. Also consider looking at
    /// `Publishers.IgnoreError`.
    public func ignoreError() -> Publishers.IgnoreError<Self> {
        return .init(upstream: self)
    }
}

extension Publisher where Failure == Never {

    /// Ignores all errors carried via a `Result` object and only returns unwrapped `success`
    /// values. Also consider looking at `Publishers.IgnoreResultErrors`.
    public func ignoreResultErrors<R, F>() -> Publishers.IgnoreResultErrors<Self, R, F>
    where Output == Result<R, F>, F: Error {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// This publisher may be used to ignore any errors of an upstream publisher and replace errors
    /// by `.finished` messages. Also consider looking at `Publisher.ignoreError()`.
    public struct IgnoreError<Upstream>: Publisher where Upstream: Publisher {

        // MARK: Types
        // swiftlint:disable nesting
        public typealias Output = Upstream.Output
        public typealias Failure = Never

        private let upstream: Upstream

        init(upstream: Upstream) {
            self.upstream = upstream
        }

        // MARK: Publisher
        public func receive<S>(subscriber: S)
        where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let subscriber = IgnoreErrorConduit<S, Upstream.Failure>(subscriber: subscriber)
            self.upstream.subscribe(subscriber)
        }
    }

    /// This publisher can be used to ignore any errors of publishers which output values as
    /// `Result` but never fail otherwise. Every time a `success` element is emitted, it is passed
    /// through to the downstream subscriber, otherwise they are ignored. Also consider looking at
    /// `Publisher.ignoreResultErrors()`.
    public struct IgnoreResultErrors<Upstream, Output, Err>: Publisher
    where Upstream: Publisher, Err: Error, Upstream.Output == Result<Output, Err>,
        Upstream.Failure == Never {

        // MARK: Types
        public typealias Failure = Never

        private let upstream: Upstream

        init(upstream: Upstream) {
            self.upstream = upstream
        }

        // MARK: Publisher
        public func receive<S>(subscriber: S)
        where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let subscriber = IgnoreErrorResultConduit<S, Output, Err>(subscriber: subscriber)
            self.upstream.subscribe(subscriber)
        }
    }
}

private struct IgnoreErrorConduit<S, Failure>: Subscriber
where S: Subscriber, Failure: Error, S.Failure == Never {

    typealias Input = S.Input

    let combineIdentifier = CombineIdentifier()
    private let subscriber: S

    init(subscriber: S) {
        self.subscriber = subscriber
    }

    func receive(subscription: Subscription) {
        subscriber.receive(subscription: subscription)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        subscriber.receive(input)
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        subscriber.receive(completion: .finished)
    }
}

private struct IgnoreErrorResultConduit<S, R, E>: Subscriber
where S: Subscriber, E: Error, S.Input == R, S.Failure == Never {

    typealias Input = Result<R, E>
    typealias Failure = S.Failure

    let combineIdentifier = CombineIdentifier()
    private let subscriber: S

    init(subscriber: S) {
        self.subscriber = subscriber
    }

    func receive(subscription: Subscription) {
        subscriber.receive(subscription: subscription)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        switch input {
        case .success(let result):
            return subscriber.receive(result)
        default:
            return .unlimited
        }
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        subscriber.receive(completion: .finished)
    }
}
