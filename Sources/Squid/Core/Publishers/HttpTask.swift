//
//  HttpTask.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation
import Combine

// MARK: Publisher
internal struct HttpTaskPublisher: Publisher {
    
    typealias Output = (data: Data, response: URLResponse)
    typealias Failure = Squid.Error
    
    private let request: HttpRequest
    private let session: URLSession
    
    init(request: HttpRequest, in session: URLSession) {
        self.request = request
        self.session = session
    }
    
    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = HttpTaskSubscription(
            subscriber: subscriber, request: self.request.urlRequest, session: self.session
        )
        subscriber.receive(subscription: subscription)
    }
}

// MARK: Subscription
fileprivate class HttpTaskSubscription<S>: Subscription
where S: Subscriber, S.Input == HttpTaskPublisher.Output, S.Failure == HttpTaskPublisher.Failure {
    
    let combineIdentifier = CombineIdentifier()
    
    private let urlSession: URLSession
    private let urlRequest: URLRequest
    private var task: URLSessionTask?
    private var subscriber: S?
    
    init(subscriber: S, request: URLRequest, session: URLSession) {
        self.urlRequest = request
        self.urlSession = session
        self.subscriber = subscriber
    }
    
    func request(_ demand: Subscribers.Demand) {
        if demand > 0 {
            let task = self.urlRequest.getTask(in: self.urlSession) {
                data, response, error -> Void in
                
                let result = processResponse(data: data, response: response, error: error)
                switch result {
                case .success(let value):
                    _ = self.subscriber?.receive(value)
                    self.subscriber?.receive(completion: .finished)
                case .failure(let error):
                    self.subscriber?.receive(completion: .failure(error))
                }
            }
            task.resume()
            self.task = task
        }
    }
    
    func cancel() {
        if self.task?.state == .running {
            self.task?.cancel()
        }
    }
}

// MARK: Fileprivate Functions
extension URLRequest {
    
    fileprivate func getTask(in session: URLSession,
                             completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionTask {
        switch self.httpMethod {
        case "PUT", "POST":
            return session.uploadTask(with: self, from: self.httpBody ?? Data(),
                                      completionHandler: completion)
        default:
            return session.dataTask(with: self, completionHandler: completion)
        }
    }
}

fileprivate func processResponse(data: Data?, response: URLResponse?,
                                 error: Error?) -> Result<(Data, URLResponse), Squid.Error> {
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
