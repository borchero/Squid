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
        let retrier = RetrierSubscriber(
            upstream: self.upstream, downstream: subscriber,
            request: self.request, retrier: self.retrier
        )
        self.upstream.subscribe(retrier)
    }
}

// MARK: Subscription
fileprivate class RetrierSubscription<Upstream, Downstream>: Subscription
where Upstream: Publisher, Downstream: Subscriber, Upstream.Output == Downstream.Input,
    Upstream.Failure == Downstream.Failure, Upstream.Failure == Squid.Error {
    
    let combineIdentifier = CombineIdentifier()
    
    private var upstreamSubscription: Subscription?
    
    init(upstreamSubscription: Subscription) {
        self.upstreamSubscription = upstreamSubscription
    }
    
    func request(_ demand: Subscribers.Demand) {
        self.upstreamSubscription?.request(demand)
    }
    
    func cancel() {
//        print("Cancelled ADDR:", Unmanaged.passUnretained(self).toOpaque())
//        self.upstreamSubscription?.cancel()
//        self.upstreamSubscription = nil
    }
}

fileprivate class RetrierSubscriber<Upstream, Downstream, RequestType>: Subscriber
where Upstream: Publisher, Downstream: Subscriber, RequestType: Request,
    Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure,
    Upstream.Failure == Squid.Error {
    
    let combineIdentifier = CombineIdentifier()
    
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    
    // MARK: Properties
    private let upstream: Upstream
    private let request: RequestType
    private var retrier: Retrier
    
    @RWLocked private var downstream: Downstream?
    @RWLocked private var cancellable: Cancellable?
    
    init(upstream: Upstream, downstream: Downstream, request: RequestType, retrier: Retrier) {
        self.upstream = upstream
        self._downstream.set(downstream)
        self.request = request
        self.retrier = retrier
    }
    
    // MARK: Subscriber
    func receive(subscription: Subscription) {
        let retrier = RetrierSubscription<Upstream, Downstream>(
            upstreamSubscription: subscription
        )
        self.downstream?.receive(subscription: retrier)
        retrier.request(.unlimited)
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
            // First, we need to check whether we ought to retry the failed request.
            // In case the request should be retried, we need to subscribe to the publisher again
            // since the original subscription got destroyed upon error.
            let cancellable = self.retrier.retry(self.request, failingWith: error)
                .sink { retry in
                    // We don't need to do anything if no retry is required. In case of a retry,
                    // we need to ensure that a downstream element is set.
                    guard retry, let downstream = self.downstream else {
                        return
                    }
                    
                    let retrier = RetrierSubscriber(
                        upstream: self.upstream, downstream: downstream,
                        request: self.request, retrier: self.retrier
                    )
                    self.upstream.subscribe(retrier)
                    
                    // Eventually, we want to force-cancel this cancellable. Do *not* perform
                    // this operation synchronously.
//                    self._cancellable.async { $0?.cancel(); $0 = nil }
                }
            
            // Do NOT assign this directly! Apparently, there is some kind of compiler bug causing
            // bad access.
            self._cancellable.write { $0 = cancellable }
        case .finished:
            // In case, the upstream publisher is finished, we simply pass this information along
            // the chain - nothing to do here.
            self.downstream?.receive(completion: completion)
        }
    }
//    
//    // MARK: Cancellation
//    func cancel() {
//        // 1) Currently active retry
//        self._cancellable.async { $0?.cancel(); $0 = nil }
//
//        // 2) The downstream subscription
//        self._downstream.async { $0 = nil }
//    }
}
