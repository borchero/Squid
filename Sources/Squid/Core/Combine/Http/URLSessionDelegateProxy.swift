//
//  URLSessionDelegateProxy.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation

internal class URLSessionDelegateProxy: NSObject, URLSessionDataDelegate {
    
    internal static let shared = URLSessionDelegateProxy()
    
    @RWLocked private var subscribers = [Int: TaskSubscription]()
    
    private override init() {
        super.init()
    }
    
    func register(_ subscription: TaskSubscription, forIdentifier identifier: Int) {
        self._subscribers.write { $0[identifier] = subscription }
    }
    
    func deregister(forIdentifier identifier: Int) {
        self._subscribers.write { $0[identifier] = nil }
    }
    
    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data
    ) {
        self.subscribers[dataTask.taskIdentifier]?.receive(data)
    }
    
    func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        self.subscribers[task.taskIdentifier]?.finalize(response: task.response, error: error)
    }
}
