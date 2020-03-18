//
//  RequestCache.swift
//  Squid
//
//  Created by Oliver Borchert on 3/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import Foundation

/// The caching service hook caches a server's response for requests for a specified time and
/// prevents requests from being sent again if they can be served from the cache. Caching is only
/// performed for GET requests as for all other requests, side-effects on the server are assumed.
public class CachingServiceHook: ServiceHook {

    private let ttl: TimeInterval
    private var cache: [AnyHashable: (timestamp: Date, value: Any)]

    /// Initializes a new hook that answers requests from the cache whenever the timestamp that they
    /// were added does not exceed the specified time to live.
    ///
    /// - Parameter ttl: The number of seconds that a cached value is valid, i.e. can safely be
    ///                  answered from the cache instead of sending it to the server again. Defaults
    ///                  to 10 minutes.
    public init(ttl: TimeInterval = 600) {
        self.ttl = ttl
        self.cache = [:]
    }

    public func onSchedule<R>(
        _ request: R, _ urlRequest: URLRequest
    ) -> R.Result? where R: Request {
        guard request.method == .get else {
            return nil
        }
        guard let cached = self.cache[urlRequest] else {
            return nil
        }
        let timestamp = Date()
        if timestamp.timeIntervalSince(cached.timestamp) <= self.ttl {
            return cached.value as? R.Result
        }
        self.cache[urlRequest] = nil
        return nil
    }

    public func onSuccess<R>(
        _ request: R, _ urlRequest: URLRequest, result: R.Result
    ) where R: Request {
        guard request.method == .get else {
            return
        }
        self.cache[urlRequest] = (Date(), result)
    }
}
