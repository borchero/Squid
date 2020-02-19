//
//  PaginationResponse.swift
//  Squid
//
//  Created by Oliver Borchert on 10/9/19.
//

import Foundation
import Combine

/// A paginator is returned whenever a request is scheduled for pagination (see
/// `Request.schedule(forPaginationWith:chunk:zeroBasedPageIndex:decode:)` or
/// `JsonRequest.schedule(forPaginationWith:chunk:zeroBasedPageIndex:paginatedType:)`).
///
/// In contrast to the `Response` publisher, this instance is no publisher itself. The
/// `Paginator.connect(with:)` needs to be called which yields a publisher that emits the
/// responses for successive pagination requests. See the method's documentation for details.
public class Paginator<BaseRequestType, PaginationType>
where BaseRequestType: Request, PaginationType: PaginatedData,
    PaginationType.DataType == BaseRequestType.Result {

    // MARK: Types
    private let base: BaseRequestType
    private let service: HttpService
    private let chunk: Int
    private let zeroBasedPageIndex: Bool
    private let _decode: (Data, BaseRequestType) throws -> PaginationType

    internal init(base: BaseRequestType, service: HttpService, chunk: Int, zeroBasedPageIndex: Bool,
                  decode: @escaping (Data, BaseRequestType) throws -> PaginationType) {
        self.base = base
        self.service = service
        self.chunk = chunk
        self.zeroBasedPageIndex = zeroBasedPageIndex
        self._decode = decode
    }

    // MARK: Instance Methods
    /// This method is used to initiate pagination calls. Once subscribed, the request for the
    /// initial page is sent automatically. Every subsequent request is sent when the given
    /// publisher emits an item. In case the publisher emits an item while a request is running,
    /// the "tick" is simply ignored.
    ///
    /// The returned publisher emits the requests' responses (one for each page, strictly
    /// chronological), i.e. the first response yields the contents of page 0, the second the one
    /// of page 1, etc. In case any request fails, the returned publisher errors out and no more
    /// pages can be requested. In case all pages have been successfully received, the publishers
    /// completes. Note that the returned publisher is shared and can therefore be subscribed to
    /// arbitraily often.
    ///
    /// A common use case for calling this function is to function as data source for a (seemingly)
    /// infinite List in SwiftUI. The publisher given to the function emits values once the user
    /// hits the bottom of the list while scrolling and the returned publisher emits ever new items.
    ///
    /// Note that this method can be called multiple times and yields independent publishers.
    /// 
    /// - Parameter ticks: The publisher that indicates the need for requesting the next page.
    public func connect<P>(with ticks: P) -> AnyPublisher<BaseRequestType.Result, Squid.Error>
    where P: Publisher, P.Failure == Never {
        let conduit = PaginatorConduit(
            base: self.base, service: self.service, chunk: self.chunk,
            zeroBasedPageIndex: self.zeroBasedPageIndex, decode: self._decode
        )
        return ticks
            .map { _ in () }
            .merge(with: Just(()))
            .setFailureType(to: Squid.Error.self)
            .filter { _ in conduit.guardState() }
            .flatMap { _ in conduit.schedule() }
            .extractData()
            .share()
            .eraseToAnyPublisher()
    }
}

private class PaginatorConduit<BaseRequestType, PaginationType>
where BaseRequestType: Request, PaginationType: PaginatedData,
    PaginationType.DataType == BaseRequestType.Result {

    private enum State {

        case waiting
        case running
        case failed
        case finishedAll
    }

    typealias ScheduleType = Publishers.HandleEvents<
        Response<PaginationRequest<BaseRequestType, PaginationType>>>

    private let base: BaseRequestType
    private let service: HttpService
    private let chunk: Int
    private let _decode: (Data, BaseRequestType) throws -> PaginationType

    private var currentPage: Int
    private var requestState = Locked<State>(.waiting)

    init(base: BaseRequestType, service: HttpService, chunk: Int, zeroBasedPageIndex: Bool,
         decode: @escaping (Data, BaseRequestType) throws -> PaginationType) {
        self.base = base
        self.service = service
        self.chunk = chunk
        self.currentPage = zeroBasedPageIndex ? 0 : 1
        self._decode = decode
    }

    func guardState() -> Bool {
        return self.requestState.locking { state in
            if state == .waiting {
                state = .running
                return true
            }
            return false
        }
    }

    func advancePage(_ data: PaginationType) {
        self.currentPage += 1
        if data.isLastPage {
            self.requestState.value = .finishedAll
        } else {
            self.requestState.value = .waiting
        }
    }

    func handleCompletion(_ completion: Subscribers.Completion<Squid.Error>) {
        switch completion {
        case .failure:
            self.requestState.value = .failed
        default:
            return
        }
    }

    func schedule() -> ScheduleType {
        let request = PaginationRequest(base: self.base, page: self.currentPage,
                                        chunk: self.chunk, decode: self._decode)
        return request.schedule(with: self.service)
            .handleEvents(receiveOutput: self.advancePage(_:),
                          receiveCompletion: self.handleCompletion(_:))
    }
}

extension Publisher where Output: PaginatedData {

    fileprivate func extractData() -> DataExtractionPublisher<Self> {
        return DataExtractionPublisher(upstream: self)
    }
}

private struct DataExtractionPublisher<Upstream>: Publisher
where Upstream: Publisher, Upstream.Output: PaginatedData {

    typealias Output = Upstream.Output.DataType
    typealias Failure = Upstream.Failure

    private let upstream: Upstream

    init(upstream: Upstream) {
        self.upstream = upstream
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscriber = DataExtractionSubscriber<S, Upstream.Output>(subscriber: subscriber)
        self.upstream.subscribe(subscriber)
    }
}

private struct DataExtractionSubscriber<S, Input>: Subscriber
where S: Subscriber, Input: PaginatedData, Input.DataType == S.Input {

    typealias Input = Input
    typealias Failure = S.Failure

    let combineIdentifier = CombineIdentifier()

    private let subscriber: S

    init(subscriber: S) {
        self.subscriber = subscriber
    }

    func receive(subscription: Subscription) {
        self.subscriber.receive(subscription: subscription)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        let demand = self.subscriber.receive(input.data)
        if input.isLastPage {
            self.subscriber.receive(completion: .finished)
        }
        return demand
    }

    func receive(completion: Subscribers.Completion<S.Failure>) {
        self.subscriber.receive(completion: completion)
    }
}
