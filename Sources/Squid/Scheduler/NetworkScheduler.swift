//
//  NetworkScheduler.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation
import Combine

internal class NetworkScheduler {

    // MARK: Static
    static let shared = NetworkScheduler()

    #if DEBUG
    private let runningIdentifier = AtomicInt()
    #endif

    // MARK: Properties
    private let lockingQueue = DispatchQueue(label: "squid-scheduler-locking-queue")
    private var sessions: [URLSessionConfiguration: URLSession] = [:]

    private let queues: [RequestPriority: DispatchQueue] = {
        return [
            .utility: DispatchQueue(
                label: "squid-scheduler-utility", qos: .utility, autoreleaseFrequency: .workItem
            ),
            .default: DispatchQueue(
                label: "squid-scheduler-default", qos: .default, attributes: .concurrent,
                autoreleaseFrequency: .workItem
            ),
            .userInitiated: DispatchQueue(
                label: "squid-scheduler-user-initiated", qos: .userInitiated,
                attributes: .concurrent, autoreleaseFrequency: .workItem
            )
        ]
    }()

    // MARK: HTTP Request
    func schedule<R>(_ request: R, service: HttpService) -> Response<R> where R: Request {
        #if DEBUG
        let requestId = self.runningIdentifier++
        #else
        let requestId = 0
        #endif

        // 1) Get static values (non-reactive)
        let session = self.lockingQueue.sync { self.getSession(for: service.sessionConfiguration) }
        let queue = self.queues[request.priority]!
        let retrier = service.retrierFactory.create(for: request)
        let subject = CurrentValueSubject<URLRequest?, Never>(nil)

        // 2) Get streams that can be derived from the static values
        let urlRequest = subject
            .filter { $0 != nil }
            .map { $0! }
            .setFailureType(to: Squid.Error.self)
        let fulfilled = urlRequest
            .flatMap { service.hook.fulfillPublisher(request, urlRequest: $0) }

        // 3) Build request chain
        let response = request
            .retriedResponsePublisher(
                service: service, session: session, retrier: retrier, subject: subject,
                requestId: requestId
            ).tryMap(request.decode)
            .mapError(Squid.Error.ensure(_:))
            .combineLatest(urlRequest)
            .handleServiceHook(service.hook, for: request)
            .map { $0.0 }
            .merge(with: fulfilled)
            .first()
            .subscribe(on: queue)

        return Response(publisher: response, request: request)
    }

    // MARK: Web Socket Request
    func schedule<R>(_ request: R, service: HttpService) -> Stream<R> where R: StreamRequest {
        #if DEBUG
        let requestId = self.runningIdentifier++
        #else
        let requestId = 0
        #endif

        // 1) Get static values (non-reactive)
        let session = self.lockingQueue.sync { self.getSession(for: service.sessionConfiguration) }
        let queue = self.queues[request.priority]!
        let socket = CurrentValueSubject<URLSessionWebSocketTask?, Never>(nil)

        // 2) Build stream request chain
        let response = request
            .responsePublisher(
                service: service, session: session, socket: socket, requestId: requestId
            ).handleFailureServiceHook(service.hook)
            .tryMap { result -> Result<R.Result, Squid.Error> in
                switch result {
                case .success(let message):
                    return .success(try request.decode(message))
                case .failure(let error):
                    return .failure(error)
                }
            }.mapError(Squid.Error.ensure(_:))
            .subscribe(on: queue)

        return Stream(publisher: response, task: socket, request: request)
    }

    // MARK: Private Methods
    private func getSession(for configuration: URLSessionConfiguration) -> URLSession {
        if let session = self.sessions[configuration] {
            return session
        }
        let session = URLSessionDelegateProxy.newSession(for: configuration)
        self.sessions[configuration] = session
        return session
    }
}
