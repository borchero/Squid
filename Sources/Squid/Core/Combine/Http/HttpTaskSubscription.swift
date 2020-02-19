//
//  HttpTaskSubscription.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation
import Combine

internal class HttpTaskSubscription<S>: Subscription
where S: Subscriber, S.Input == HttpTaskPublisher.Output, S.Failure == HttpTaskPublisher.Failure {

    private let urlSession: URLSession
    private let urlRequest: URLRequest
    private var task: URLSessionTask?
    private var subscriber: S?
    private var taskWasScheduled = false

    private var data: Data?

    init(subscriber: S, request: URLRequest, session: URLSession) {
        self.urlRequest = request
        self.urlSession = session
        self.subscriber = subscriber
    }

    func request(_ demand: Subscribers.Demand) {
        // We do not need to look `taskWasScheduled` as long as there is a single subscription
        // --> this should be the case
        guard demand > 0, !self.taskWasScheduled else {
            return
        }
        let task = self.urlRequest.getTask(in: self.urlSession)
        URLSessionDelegateProxy[self.urlSession].register(
            self, forIdentifier: task.taskIdentifier
        )
        task.resume()
        self.task = task
        self.taskWasScheduled = true
    }

    func cancel() {
        if self.task?.state == .running {
            self.task?.cancel()
        }
        self.subscriber = nil
    }

    deinit {
        // swiftlint:disable identifier_name
        if let id = self.task?.taskIdentifier {
            URLSessionDelegateProxy[self.urlSession].deregister(forIdentifier: id)
        }
        self.cancel()
    }
}

extension HttpTaskSubscription: HttpTaskSubscriptionDelegate {

    func receive(_ data: Data) {
        if let currentData = self.data {
            self.data = currentData + data
        } else {
            self.data = data
        }
    }

    func finalize(response: URLResponse?, error: Error?) {
        let result = self.processResponse(data: self.data, response: response, error: error)
        switch result {
        case .success(let value):
            _ = self.subscriber?.receive(value)
            self.subscriber?.receive(completion: .finished)
        case .failure(let error):
            self.subscriber?.receive(completion: .failure(error))
        }
    }
}

extension HttpTaskSubscription {

    private func processResponse(
        data: Data?, response: URLResponse?, error: Error?
    ) -> Result<(Data, URLResponse), Squid.Error> {
        if let error = error as NSError? {
            switch URLError.Code(rawValue: error.code) {
            case .timedOut:
                return .failure(.timeout)
            case .notConnectedToInternet:
                return .failure(.noConnection)
            case .badURL:
                return .failure(.invalidUrl)
            case .cannotFindHost:
                return .failure(.unknownHost)
            default:
                return .failure(.unknown(error as Error))
            }
        }

        guard let response = response else {
            return .failure(.invalidResponse)
        }

        return .success((data ?? Data(), response))
    }
}

extension URLRequest {

    fileprivate func getTask(in session: URLSession) -> URLSessionTask {
        switch self.httpMethod {
        case "PUT", "POST":
            return session.uploadTask(with: self, from: self.httpBody ?? Data())
        default:
            return session.dataTask(with: self)
        }
    }
}
