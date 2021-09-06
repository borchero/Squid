//
//  PaginationResponse.swift
//  Squid
//
//  Created by Oliver Borchert on 10/9/19.
//

import Foundation
import Combine

public enum PaginationPointer {
    case previous
    case next
}

/// A paginator is returned whenever a request is scheduled for pagination (see
/// `Request.schedule(forPaginationWith:chunk:zeroBasedPageIndex:decode:)` or
/// `JsonRequest.schedule(forPaginationWith:chunk:zeroBasedPageIndex:paginatedType:)`).
///
/// In contrast to the `Response` publisher, this instance is no publisher itself. The
/// `Paginator.connect(with:)` needs to be called which yields a publisher that emits the
/// responses for successive pagination requests. See the method's documentation for details.
public class Paginator<CoordinatorType, ServiceType>
where CoordinatorType: PaginationCoordinator, ServiceType: HttpService {

    // MARK: Types
    private let base: CoordinatorType.BaseRequest
    private let service: ServiceType
    private let coordinator: CoordinatorType

    internal init(
        base: CoordinatorType.BaseRequest,
        coordinator: CoordinatorType,
        service: ServiceType
    ) {
        self.base = base
        self.coordinator = coordinator
        self.service = service
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
    /// pages can be requested. In case all pages have been successfully received, the publisher
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
    public func connect<P>(
        with ticks: P
    ) -> AnyPublisher<CoordinatorType.BaseRequest.Result, ServiceType.RequestError>
    where P: Publisher, P.Failure == Never {
        let conduit = PaginatorConduit(
            base: self.base,
            coordinator: self.coordinator,
            service: self.service
        )

        return ticks
            .map { _ in () }
            .merge(with: Just(()))
            .setFailureType(to: ServiceType.RequestError.self)
            .filter { _ in conduit.guardState() }
            .flatMap { _ in conduit.schedule(pointer: .next) }
            .extractData()
            .share()
            .eraseToAnyPublisher()
    }
}

private class PaginatorConduit<CoordinatorType, ServiceType>
where CoordinatorType: PaginationCoordinator, ServiceType: HttpService {

    private enum State {
        case waiting
        case running
        case failed
        case finishedAll
    }

    typealias ScheduleType = Publishers.HandleEvents<Response<CoordinatorType.PaginatedRequest, ServiceType>>

    private let base: CoordinatorType.BaseRequest
    private let coordinator: CoordinatorType
    private let service: ServiceType

    private var requestState = Locked<State>(.waiting)

    private var previousData: CoordinatorType.PaginationType?

    init(base: CoordinatorType.BaseRequest, coordinator: CoordinatorType, service: ServiceType) {
        self.base = base
        self.coordinator = coordinator
        self.service = service
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

    func handlePage(_ data: CoordinatorType.PaginationType) {
        self.previousData = data

        self.requestState.value = data.isLastPage ? .finishedAll : .waiting
    }

    func handleCompletion(_ completion: Subscribers.Completion<ServiceType.RequestError>) {
        switch completion {
        case .failure:
            self.requestState.value = .failed
        default:
            return
        }
    }

    func schedule(pointer: PaginationPointer) -> ScheduleType {
        let request = coordinator.pageRequest(
            from: self.base,
            pointer: pointer,
            previousData: self.previousData
        )

        return request.schedule(with: self.service)
            .handleEvents(receiveOutput: self.handlePage(_:),
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
