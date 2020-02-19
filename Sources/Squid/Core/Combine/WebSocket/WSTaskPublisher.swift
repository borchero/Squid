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
