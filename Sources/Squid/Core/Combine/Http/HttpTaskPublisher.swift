//
//  HttpTaskPublisher.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation
import Combine

// This publisher should be subscribed to *once*. Do *not* expose this publisher in a public
// interface without using some kind of multicast publisher in the pipeline.
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
