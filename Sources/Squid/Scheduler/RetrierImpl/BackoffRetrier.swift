//
//  BackoffRetrier.swift
//  Squid
//
//  Created by Oliver Borchert on 9/19/19.
//

import Foundation
import Combine

/// The backoff retrier is a more complex, stateful retrier that retries a request upon certain
/// failures by waiting a specified period of time defined by its strategy (see
/// `BackoffRetrier.Strategy`). It also defines a maximum duration after which a failed request
/// is deemed unsuccessful.
public class BackoffRetrier: Retrier {

    // MARK: Static Methods
    /// Initializes a new factory yielding instances of backoff retriers for requests.
    ///
    /// - Parameter strategy: The strategy to use for the backoff retrier. Defaults to
    ///                       `.exponentialBinary`.
    /// - Parameter maxBackoff: The maximum backoff duration. After this time, requests are not
    ///                         retried any more. Defaults to 10 minutes.
    /// - Parameter retryCondition: A closure evaluating whether to attempt a retry based on the
    ///                             error causing the request to fail. Defaults to
    ///                             `defaultRetryCondition(_:)`.
    public static func factory(
        strategy: Strategy = .exponentialBinary, maxBackoff: TimeInterval = 600,
        retryCondition: @escaping (Squid.Error) -> Bool = defaultRetryCondition
    ) -> RetrierFactory {
        return AnyRetrierFactory {
            return BackoffRetrier(strategy: strategy, maxBackoff: maxBackoff,
                                  retryCondition: retryCondition)
        }
    }

    /// Defines the default condition that a request is retried based on the error that has occured.
    /// Retrying by backing off is attempted in the case of:
    ///
    ///  1. No Connection (i.e. bad internet)
    ///  2. Timeout (i.e. server possibly down)
    ///  3. Unknown Error
    ///  4. Status Code 429 (i.e. throttling)
    ///
    /// - Parameter error: The error that caused the failure of the request, used to decide whether
    ///                    the request ought to be retried.
    public static func defaultRetryCondition(_ error: Squid.Error) -> Bool {
        switch error {
        case .noConnection, .timeout, .unknown:
            return true
        case .requestFailed(statusCode: 429, response: _):
            return true
        default:
            return false
        }
    }

    private let strategy: Strategy
    private let maxBackoff: TimeInterval
    private let retryCondition: (Squid.Error) -> Bool
    private var backoffDuration: TimeInterval

    internal init(strategy: Strategy, maxBackoff: TimeInterval,
                  retryCondition: @escaping (Squid.Error) -> Bool) {
        self.strategy = strategy
        self.maxBackoff = maxBackoff
        self.retryCondition = retryCondition
        self.backoffDuration = strategy.initial
    }

    // MARK: Retrier
    public func retry<R>(
        _ request: R, failingWith error: Squid.Error
    ) -> Future<Bool, Never> where R: Request {
        let duration = self.backoffDuration
        let attemptsRetry = duration < self.maxBackoff
        self.backoffDuration = self.strategy.next(duration)

        let requiresRetry = self.retryCondition(error)

        return Future { promise in
            guard attemptsRetry, requiresRetry else {
                promise(.success(false))
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + duration) {
                promise(.success(true))
            }
        }
    }
}

extension BackoffRetrier {

    /// The strategy of a backoff retrier essentially defines the time to wait before repeating the
    /// request.
    public enum Strategy {

        /// The exponential binary strategy starts by waiting one second. After each successive
        /// failure of the request, it backs off twice as long as before.
        case exponentialBinary

        var initial: TimeInterval {
            switch self {
            case .exponentialBinary:
                return 1
            }
        }

        func next(_ current: TimeInterval) -> TimeInterval {
            switch self {
            case .exponentialBinary:
                return current * 2
            }
        }
    }
}

extension BackoffRetrier {

    public var allowsMultipleRetries: Bool {
        return true
    }
}
