//
//  WebSocketTask.swift
//  Squid
//
//  Created by Oliver Borchert on 10/5/19.
//

import Foundation
import Combine

// This publisher should be subscribed to *once*. Do *not* expose this publisher in a public
// interface without using some kind of multicast publisher in the pipeline.
internal struct WSTaskPublisher: Publisher {

    typealias Output = Result<URLSessionWebSocketTask.Message, Squid.Error>
    typealias Failure = Squid.Error

    private let request: HttpRequest
    private let session: URLSession

    // The `taskSubject` is used to "tunnel" the network task to a downstream publisher which
    // enables sending data using this task
    private let taskSubject: CurrentValueSubject<URLSessionWebSocketTask?, Never>

    init(request: HttpRequest, in session: URLSession,
         taskSubject: CurrentValueSubject<URLSessionWebSocketTask?, Never>) {
        self.request = request
        self.session = session
        self.taskSubject = taskSubject
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = WSTaskSubscription(
            subscriber: subscriber, request: self.request.urlRequest, session: self.session,
            taskSubject: self.taskSubject
        )
        subscriber.receive(subscription: subscription)
    }
}

// MARK: Extensions
extension Publisher where Output == WSTaskPublisher.Output {

    func debugItem<R>(of request: R, requestId: Int) -> Publishers.HandleEvents<Self> where R: StreamRequest {
        return self.handleEvents(receiveOutput: { result in
            switch result {
            case .success(let message):
                Squid.Logger.shared.log(
                    "Stream `\(type(of: request))` with identifier \(requestId) received message:\n" +
                    "- Message: \(message)".indent(spaces: 4)
                )
            case .failure(let error):
                Squid.Logger.shared.log(
                    "Stream `\(type(of: request))` with identifier \(requestId) received error:\n" +
                    "- Error: \(error)".indent(spaces: 4)
                )
            }
        }, receiveCompletion: { completion in
            guard case .failure(let error) = completion else {
                return
            }
            Squid.Logger.shared.log(
                "Cancelled stream `\(type(of: request))` with identifier \(requestId):\n" +
                "- Error: \(error)".indent(spaces: 4)
            )
        })
    }
}
