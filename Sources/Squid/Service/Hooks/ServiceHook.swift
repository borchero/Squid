//
//  ServiceHook.swift
//  Squid
//
//  Created by Oliver Borchert on 3/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import Foundation
import Combine

/// A service hook represents a component that is called at specific events during the processing
/// of a request. A service hook can be attached to a service to e.g. provide caching behavior.
public protocol ServiceHook {

    /// The method is called right before a request is scheduled. It may return the result type of
    /// a request to prematurely fulfill it. That means, whenever a non-nil value is returned, the
    /// request is *not* sent over the wire but the returned value will be returned instead. No
    /// failures can occur after returning a non-nil value here.
    ///
    /// - Parameter request: The request object that was scheduled.
    /// - Parameter urlRequest: The URL request that would be sent to the server. Contains all
    ///                         headers, the exact body, etc.
    ///
    /// - Note: When calling `schedule(with:)` on a request, this method is *not* guaranteed to be
    ///         called. If building the URL request fails for some reason (e.g. the body cannot be
    ///         constructed), no method invocation will occur.
    ///
    /// - Attention: Internally, the request is actually started to be sent simultaneously with this
    ///              method call. If the response of this function takes too long, the server's
    ///              response might get called. As soon as this method returns, however, the request
    ///              will be cancelled.
    func onSchedule<R>(_ request: R, _ urlRequest: URLRequest) -> R.Result? where R: Request

    /// This method is called whenever a request was successfully finished, i.e. a valid response
    /// has been recorded from the server. This method will *not* be called when the result was
    /// returned by `onSchedule(_:_:)`.
    ///
    /// - Parameter request: The request object that was scheduled.
    /// - Parameter urlRequest: The URL request that was sent to the server.
    /// - Parameter result: The decoded result returned by the server.
    func onSuccess<R>(_ request: R, _ urlRequest: URLRequest, result: R.Result) where R: Request

    /// This method is called whenever a failure occurs when scheduling a `Request` or a
    /// `StreamRequest`. The error might indicate e.g. network outage that should be displayed to
    /// the user.
    ///
    /// - Parameter error: The error that caused a request to fail.
    func onFailure(_ error: Error)
}

extension ServiceHook {

    /// By default, `nil` is returned always, allowing the request to be sent to the server.
    public func onSchedule<R>(_ request: R,
                              _ urlRequest: URLRequest) -> R.Result? where R: Request {
        return nil
    }

    /// By default, no operation is performed.
    public func onSuccess<R>(_ request: R, _ urlRequest: URLRequest,
                             result: R.Result) where R: Request {
        return
    }

    /// By default, no operation is performed.
    public func onFailure(_ error: Error) {
        return
    }
}

// MARK: Internal
extension ServiceHook {

    internal func fulfillPublisher<R>(
        _ request: R, urlRequest: URLRequest
    ) -> Deferred<AnyPublisher<R.Result, Squid.Error>> where R: Request {
        return Deferred {
            if let fulfilled = self.onSchedule(request, urlRequest) {
                return Just(fulfilled).setFailureType(to: Squid.Error.self).eraseToAnyPublisher()
            }
            return Empty().eraseToAnyPublisher()
        }
    }
}

extension Publisher {

    internal func handleServiceHook<R>(
        _ hook: ServiceHook, for request: R
    ) -> Publishers.HandleEvents<Self> where R: Request, Output == (R.Result, URLRequest) {
        return self.handleEvents(
            receiveOutput: { output in
                hook.onSuccess(request, output.1, result: output.0)
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    hook.onFailure(error)
                }
            })
    }

    internal func handleFailureServiceHook<R, E>(
        _ hook: ServiceHook
    ) -> Publishers.HandleEvents<Self> where E: Error, Output == Result<R, E> {
        return self.handleEvents(
            receiveOutput: { output in
                if case .failure(let error) = output {
                    hook.onFailure(error)
                }
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    hook.onFailure(error)
                }
            })
    }
}
