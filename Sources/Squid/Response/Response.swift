//
//  Response.swift
//  Squid
//
//  Created by Oliver Borchert on 9/18/19.
//

import Foundation
import Combine

/// An instance of the response class is returned whenever a `Request` is scheduled. The response
/// is a `ConnectablePublisher` with the request's result type as output. In the future, the set of
/// available properties and methods on an instance of the response may be extended.
///
/// As there is only a single response no matter the number of subscribers, the response is
/// represented as a class (i.e. it is a shared publisher). Note that the actual scheduling of the
/// request is performed upon the first subscription. Subscribers that subscribe at a later point in
/// time receive the result as soon as it is available and do not send the request again.
///
/// Lastly, the class cannot be initialized by the user but is only returned by Squid upon
/// scheduling a request.
public class Response<RequestType>: Publisher where RequestType: Request {

    // MARK: Types
    public typealias Output = RequestType.Result
    public typealias Failure = Squid.Error

    private let publisher: AnyPublisher<Output, Failure>
    private let request: RequestType

    internal init<P>(publisher: P, request: RequestType)
    where P: Publisher, P.Output == Output, P.Failure == Failure {
        self.publisher = publisher.shareReplayLatest()
        self.request = request
    }

    // MARK: Publisher
    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.publisher.receive(subscriber: subscriber)
    }
}
