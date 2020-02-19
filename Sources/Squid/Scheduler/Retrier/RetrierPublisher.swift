//
//  RetrierPublisher.swift
//  Squid
//
//  Created by Oliver Borchert on 9/19/19.
//

import Foundation
import Combine

extension Publisher where Failure == Squid.Error {

    internal func retryOnFailure<R>(request: R, retrier: Retrier) -> RetrierPublisher<Self, R>
    where R: Request {
        return RetrierPublisher(upstream: self, request: request, retrier: retrier)
    }
}

// MARK: Publisher
internal struct RetrierPublisher<Upstream, RequestType>: Publisher
where Upstream: Publisher, Upstream.Failure == Squid.Error, RequestType: Request {

    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure

    private let upstream: Upstream
    private let request: RequestType
    private let retrier: Retrier

    init(upstream: Upstream, request: RequestType, retrier: Retrier) {
        self.upstream = upstream
        self.request = request
        self.retrier = retrier
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let retrier = RetrierConduit(
            upstream: self.upstream, downstream: subscriber,
            request: self.request, retrier: self.retrier
        )
        self.upstream.subscribe(retrier)
    }
}

// MARK: Subscription
private class RetrierConduit<Upstream, Downstream, RequestType>: Subscriber, Subscription
where Upstream: Publisher, Downstream: Subscriber, RequestType: Request,
    Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure,
    Upstream.Failure == Squid.Error {

    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure

    // MARK: Properties
    private var downstream: Downstream?
    private var subscription: Subscription?
    private var cancellable: Cancellable?

    private let upstream: Upstream
    private let request: RequestType
    private let retrier: Retrier

    private var isFirstRetry = true
    private var postponeCancel = false

    init(upstream: Upstream, downstream: Downstream, request: RequestType, retrier: Retrier) {
        self.upstream = upstream
        self.downstream = downstream
        self.request = request
        self.retrier = retrier
    }

    // MARK: Subscriber
    func receive(subscription: Subscription) {
        self.subscription = subscription
        self.downstream?.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        // In case of a result being received, we simply pass the result along the chain - nothing
        // to do here.
        return self.downstream?.receive(input) ?? .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .failure(let error):
            // In case of failure, the retrier actually comes alive.
            // First, let's check whether the retrier allows multiple retries.
            guard self.isFirstRetry || self.retrier.allowsMultipleRetries else {
                self.downstream?.receive(completion: completion)
                return
            }
            self.isFirstRetry = false

            // First, we need to check whether we ought to retry the failed request.
            // In case the request should be retried, we need to subscribe to the publisher again
            // since the original subscription got destroyed upon error.
            self.cancellable = self.retrier.retry(self.request, failingWith: error)
                .sink { retry in
                    // We don't need to do anything if no retry is required.
                    guard retry else {
                        self.downstream?.receive(completion: completion)
                        return
                    }

                    // We simply subscribe to the upstream once again. Here, we also need to
                    // request from the upstream subscription again.
                    self.postponeCancel = true
                    self.upstream.subscribe(self)
                    self.subscription?.request(.unlimited)
                }
        case .finished:
            // In case, the upstream publisher is finished, we simply pass this information along
            // the chain - nothing to do here.
            self.downstream?.receive(completion: completion)
        }
    }

    // MARK: Subscription
    func request(_ demand: Subscribers.Demand) {
        self.subscription?.request(demand)
    }

    func cancel() {
        // We only cancel subscriptions and downstream subscribers when there is no new subscription
        guard !self.postponeCancel else {
            self.postponeCancel = false
            return
        }
        self.subscription = nil
        self.downstream = nil
    }
}
