//
//  URLSessionDelegateProxy.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation

internal class URLSessionDelegateProxy: NSObject, URLSessionDataDelegate,
    URLSessionWebSocketDelegate {

    // MARK: Static
    private static var proxies = Locked<[URLSession: URLSessionDelegateProxy]>([:])

    internal static func newSession(for configuration: URLSessionConfiguration) -> URLSession {
        let proxy = URLSessionDelegateProxy()
        let session = URLSession(configuration: configuration, delegate: proxy, delegateQueue: nil)
        proxies.locking { $0[session] = proxy }
        return session
    }

    internal static subscript(session: URLSession) -> URLSessionDelegateProxy {
        return proxies.locking { $0[session]! }
    }

    // MARK: Instance
    private let httpSubscribers = Locked<[Int: HttpTaskSubscriptionDelegate]>([:])
    private let wsSubscribers = Locked<[Int: WSTaskSubscriptionDelegate]>([:])

    private override init() {
        super.init()
    }

    func register(_ subscription: HttpTaskSubscriptionDelegate, forIdentifier identifier: Int) {
        self.httpSubscribers.locking { $0[identifier] = subscription }
    }

    func register(_ subscription: WSTaskSubscriptionDelegate, forIdentifier identifier: Int) {
        self.wsSubscribers.locking { $0[identifier] = subscription }
    }

    func deregister(forIdentifier identifier: Int) {
        self.httpSubscribers.locking { $0[identifier] = nil }
        self.wsSubscribers.locking { $0[identifier] = nil }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.httpSubscribers.value[dataTask.taskIdentifier]?.receive(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        self.httpSubscribers.value[task.taskIdentifier]?.finalize(
            response: task.response, error: error
        )
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.wsSubscribers.value[webSocketTask.taskIdentifier]?.close(
            with: closeCode, reason: reason
        )
    }
}
