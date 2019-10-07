//
//  Response.swift
//  Squid
//
//  Created by Oliver Borchert on 9/18/19.
//

import Foundation
import Combine

/// An instance of the response class is returned whenever a `Request` is scheduled. The response
/// is a simple `Publisher` of the request's result type which currently provides a single `expect`
/// function in addition to a publisher's default functions. In the future, the set of available
/// properties and methods on an instance of the response may be extended. The publisher has the
/// same behavior as a `Future`: it either yields a single value and then completes, or errors out.
/// As there is only a single response no matter the number of subscriber, the response is
/// represented as a class (i.e. it is a shared publisher). Further, the class cannot be initialized
/// by the user but is only returned by Squid upon scheduling a request.
public class Response<RequestType>: Publisher where RequestType: Request {
    
    public typealias Output = RequestType.Result
    public typealias Failure = Squid.Error
    
    private let publisher: AnyPublisher<Output, Failure>
    private let request: RequestType
    
    internal init<P>(publisher: P, request: RequestType)
    where P: Publisher, P.Output == Output, P.Failure == Failure {
        self.publisher = publisher.eraseToAnyPublisher()
        self.request = request
    }
    
    // MARK: Instance Methods
    public func receive<S>(subscriber: S)
    where S: Subscriber,Failure == S.Failure, Output == S.Input {
        self.publisher.receive(subscriber: subscriber)
    }
    
    /// Provides a convenient way to subscribe to the result of a request while disregarding any
    /// errors that may occur. Usually, the use of this function is discouraged in a production
    /// environment.
    /// The function returns the `Cancellable` produced by the `sink` method on this publisher.
    ///
    /// - Parameter execute: A closure which is executed when there is no error. The request's
    ///                      result is passed as single parameter.
    @discardableResult
    public func expect(_ execute: @escaping (RequestType.Result) -> Void) -> Cancellable {
        return self.sink(receiveCompletion: { _ in }, receiveValue: execute)
    }
}
