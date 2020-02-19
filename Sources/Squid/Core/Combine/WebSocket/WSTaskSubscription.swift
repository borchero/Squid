//
//  WSTaskSubscription.swift
//  Squid
//
//  Created by Oliver Borchert on 10/8/19.
//

import Foundation
import Combine

internal class WSTaskSubscription<S>: Subscription
where S: Subscriber, S.Input == WSTaskPublisher.Output, S.Failure == WSTaskPublisher.Failure {

    private let urlSession: URLSession
    private let urlRequest: URLRequest
    private let taskSubject: CurrentValueSubject<URLSessionWebSocketTask?, Never>
    private var task: URLSessionWebSocketTask?
    private var subscriber: S?
    private var taskWasScheduled = false

    private var data: Data?

    init(subscriber: S, request: URLRequest, session: URLSession,
         taskSubject: CurrentValueSubject<URLSessionWebSocketTask?, Never>) {
        self.urlRequest = request
        self.urlSession = session
        self.subscriber = subscriber
        self.taskSubject = taskSubject
    }

    func request(_ demand: Subscribers.Demand) {
        // Again, we do not need to lock `taskWasScheduled` as there should only be a single
        // subscriber to this susbcription
        guard demand > 0, !self.taskWasScheduled else {
            return
        }
        let task = self.urlRequest.getTask(in: self.urlSession)
        URLSessionDelegateProxy[self.urlSession].register(
            self, forIdentifier: task.taskIdentifier
        )
        task.resume()
        self.task = task
        self.taskSubject.send(task)
        self.listen()
        self.taskWasScheduled = true
    }

    func cancel() {
        if self.task?.state == .running {
            self.task?.cancel(with: .goingAway, reason: nil)
        }
    }

    private func listen() {
        self.task?.receive(completionHandler: { [weak self] result in
            let finalResult = { () -> S.Input in
                switch result {
                case .success(let message):
                    return .success(message)
                case .failure(let error):
                    return .failure(.ensure(error))
                }
            }()
            _ = self?.subscriber?.receive(finalResult)
            self?.listen()
        })
    }

    deinit {
        // swiftlint:disable identifier_name
        if let id = self.task?.taskIdentifier {
            URLSessionDelegateProxy[self.urlSession].deregister(forIdentifier: id)
        }
        self.cancel()
    }
}

extension WSTaskSubscription: WSTaskSubscriptionDelegate {

    func close(with error: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.subscriber?.receive(completion: .failure(.closedStream(code: error)))
    }
}

extension URLRequest {

    fileprivate func getTask(in session: URLSession) -> URLSessionWebSocketTask {
        return session.webSocketTask(with: self)
    }
}
