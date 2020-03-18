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

    typealias Output = (data: Data, response: HTTPURLResponse)
    typealias Failure = Squid.Error

    private let request: URLRequest
    private let session: URLSession

    init(request: URLRequest, in session: URLSession) {
        self.request = request
        self.session = session
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = HttpTaskSubscription(
            subscriber: subscriber, request: self.request, session: self.session
        )
        subscriber.receive(subscription: subscription)
    }
}

// MARK: Extensions
extension Publisher where Output == (data: Data, response: HTTPURLResponse) {

    func debug<R>(request: R, requestId: Int) -> Publishers.HandleEvents<Self> where R: Request {
        return self.handleEvents(receiveOutput: { result in
            Squid.Logger.shared.log(
                "Finished request `\(type(of: request))` with identifier \(requestId):\n" +
                result.response.description(for: result.data).indent(spaces: 4)
            )
        }, receiveCompletion: { completion in
            guard case .failure(let error) = completion else {
                return
            }
            Squid.Logger.shared.log(
                "Finished request `\(type(of: request))` with identifier \(requestId):\n" +
                "- Unknown error: \(error)".indent(spaces: 4)
            )
        })
    }
}

extension HTTPURLResponse {

    fileprivate func description(for data: Data) -> String {
        let headerString = (self.allHeaderFields as? [String: String])?
            .httpHeaderDescription?.indent(spaces: 12, skipLines: 1)
        var body = data.prettyPrintedJson.map { "\n" + $0.indent(spaces: 12) }
        if body == nil {
            body = String(data: data, encoding: .utf8)?.truncate(to: 1000)
        }

        return """
        - Status:   \(self.statusCode)
        - Headers:  \(headerString ?? "<none>")
        - Body:     <\(data.count) bytes>\(body ?? "")
        """
    }
}

extension Data {

    fileprivate var prettyPrintedJson: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []) else {
            return nil
        }
        guard let data =
            try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) else {
                return nil
        }
        return String(bytes: data, encoding: .utf8)?.truncate(to: 1000)
    }
}
