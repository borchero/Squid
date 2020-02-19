//
//  Stream.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation
import Combine

/// An instance of the stream class is returned whenever a `StreamRequest` is scheduled. The stream
/// publisher produces arbitrarily many values (depending on the messages from the connected peer).
/// The publisher also provides additional `send` methods to enable bidirectional communication.
/// Note that publisher *only* errors out if the stream fails and continues to exist if single
/// messages from the peer cause an error. This is the reason for the stream's output to be of the
/// type `Result`. Also note that the publisher never completes.
///
/// Note that, in contrast to the `Response` publisher, this publisher does *not* replay any
/// messages received.
public class Stream<StreamRequestType>: Publisher where StreamRequestType: StreamRequest {

    // MARK: Types
    public typealias Failure = Squid.Error
    public typealias Output = Result<StreamRequestType.Result, Squid.Error>

    private let publisher: AnyPublisher<Output, Failure>
    private let request: StreamRequestType
    private var sendCancellables = Locked<Set<AnyCancellable>>([])

    // We need to get access to the task like this since the task itself will not be available at
    // the time of the initialization of this class. Hence, we cannot pass the task directly via
    // the initializer.
    private let taskCancellable: Cancellable
    private let task = CurrentValueSubject<URLSessionWebSocketTask?, Never>(nil)

    internal init<P, F>(publisher: P, task: F, request: StreamRequestType)
    where P: Publisher, P.Output == Output, P.Failure == Failure, F: Publisher,
    F.Output == URLSessionWebSocketTask?, F.Failure == Never {
        self.publisher = publisher.share().eraseToAnyPublisher()
        self.request = request
        self.taskCancellable = task.subscribe(self.task)
    }

    // MARK: Instance Methods
    /// This simple variant of the `send` method sends a message to the peer to which the WebSocket
    /// is connected. The result is a publisher which never errors out. Whether the request was
    /// successful can be deduced from the publisher's *single* returned `Result` instance.
    /// Note that the returned publishers is shared and replays the result.
    ///
    /// - Parameter message: The message to send to the peer.
    public func send(
        _ message: StreamRequestType.Message
    ) -> AnyPublisher<Result<Void, Squid.Error>, Never> {
        return Future { promise in
            do {
                let encoded = try self.request.encode(message)
                self.sendCancellables.locking { set in
                    self.task
                        .filter { $0 != nil }.map { $0! }.first()
                        .sink { task in
                            task.send(encoded) { error in
                                if let error = error {
                                    promise(.success(.failure(.ensure(error))))
                                } else {
                                    promise(.success(.success(())))
                                }
                            }
                        }.store(in: &set)
                }
            } catch {
                promise(.success(.failure(.ensure(error))))
            }
        }.shareReplayLatest()
    }

    /// This variant of the `send` method provides a more reactive approach towards sending messages
    /// to a peer. Every value emitted by the publisher will be sent via the `Stream.send(_:)`
    /// method and the response will be emitted by the publisher returned by this method. Note that,
    /// due to missing documentation on Apple's side, we cannot guarantee that the order of the
    /// items emitted by the returned publisher is the same as the order of the items emitted by the
    /// upstream publisher. Also, the returned publisher will never fail. The user is responsible
    /// for cancelling the subscription as soon as the stream is cancelled.
    ///
    /// - Parameter source: The upstream publisher which emits item to be sent to the peer.
    public func send<P>(from source: P) -> some Publisher
    where P: Publisher, P.Output == StreamRequestType.Message, P.Failure == Never {
        return source.flatMap(self.send(_:))
    }

    // MARK: Publisher
    public func receive<S>(subscriber: S)
    where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.publisher.receive(subscriber: subscriber)
    }

    deinit {
        _ = self.task.subscribe(on: ImmediateScheduler.shared).sink { task in
            task?.cancel()
        }
    }
}
