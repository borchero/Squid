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
        #endif

        // 1) Build HTTP request
        let asyncHeader = service.asyncHeader.mapError(Squid.Error.ensure(_:))
        let httpRequest = asyncHeader.attachToHttpRequest(request, service: service)

        // 2) Get URL session
        let session = self.lockingQueue.sync { self.getSession(for: service.sessionConfiguration) }

        // 3) Submit task
        #if DEBUG
        let task = httpRequest
            .debug(request: request, withId: requestId)
            .flatMap { return HttpTaskPublisher(request: $0, in: session) }
        #else
        let task = httpRequest
            .flatMap { return HttpTaskPublisher(request: $0, in: session) }
        #endif

        // 3.1) Debug response if necessary
        #if DEBUG
        let httpTask = task
            .httpResponse()
            .debugResponse(of: request, withId: requestId)
        #else
        let httpTask = task
            .httpResponse()
        #endif

        // 4) Check for response code
        let validatedResponse = httpTask
            .validate(statusCodeIn: request.acceptedStatusCodes)

        // 5) Run retriers if necessary
        let retriedResponse = validatedResponse
            .retryOnFailure(request: request, retrier: service.retrierFactory.create(for: request))

        // 6) Process error in service context
        let processedResponse = retriedResponse
            .handleEvents(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    service.process(error)
                default:
                    return
                }
            })

        // 7) Decode for required type
        let decodedResponse = processedResponse
            .tryMap(request.decode)
            .mapError(Squid.Error.ensure)

        // 8) Dispatch onto background thread depending on priority
        let dispatchedResponse = decodedResponse
            .subscribe(on: self.queues[request.priority]!)

        return Response(publisher: dispatchedResponse, request: request)
    }

    // MARK: Web Socket Request
    // swiftlint:disable function_body_length
    func schedule<R>(_ request: R, service: HttpService) -> Stream<R> where R: StreamRequest {
        #if DEBUG
        let requestId = self.runningIdentifier++
        #endif

        // 1) Build WebSocket request
        let asyncHeader = service.asyncHeader.mapError(Squid.Error.ensure(_:))
        let httpRequest = asyncHeader.attachToStreamRequest(request, service: service)

        // 2) Get URL session
        let session = self.lockingQueue.sync { self.getSession(for: service.sessionConfiguration) }

        // 3) Submit task - somehow, we need to capture the task here
        let taskSubject = CurrentValueSubject<URLSessionWebSocketTask?, Never>(nil)
        #if DEBUG
        let task = httpRequest
            .debug(request: request, withId: requestId)
            .flatMap { return WSTaskPublisher(request: $0, in: session, taskSubject: taskSubject) }
        #else
        let task = httpRequest
            .flatMap { return WSTaskPublisher(request: $0, in: session, taskSubject: taskSubject) }
        #endif

        // 3.1) Debug messages if necessary
        #if DEBUG
        let debuggedTask = task
            .debugItem(of: request, withId: requestId)
        #else
        let debuggedTask = task
        #endif

        // 4) Process error
        let processedResponse = debuggedTask
            .handleEvents(receiveOutput: { result in
                switch result {
                case .failure(let error):
                    service.process(error)
                default:
                    return
                }
            }, receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    service.process(error)
                default:
                    return
                }
            })

        // 5) Decode for required type
        let decodedResponse = processedResponse
            .tryMap({ result -> Result<R.Result, Squid.Error> in
                switch result {
                case .success(let message):
                    return .success(try request.decode(message))
                case .failure(let error):
                    return .failure(error)
                }
            })
            .mapError(Squid.Error.ensure)

        // 6) Dispatch onto background thread depending on priority
        let dispatchedResponse = decodedResponse
            .subscribe(on: self.queues[request.priority]!)

        return Stream(publisher: dispatchedResponse, task: taskSubject, request: request)
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

// MARK: Extensions
extension Publisher where Output == HttpRequest {

    // swiftlint:disable identifier_name
    func debug<R, N>(request: R, withId id: N) -> Publishers.HandleEvents<Self>
    where R: NetworkRequest, N: Numeric {
        return self.handleEvents(receiveOutput: { httpRequest in
            Squid.Logger.shared.log(
                "Scheduled request `\(type(of: request))` with identifier \(id):\n" +
                httpRequest.description.indent(spaces: 4)
            )
        })
    }
}

extension Publisher where Output == (data: Data, response: URLResponse), Failure == Squid.Error {

    func httpResponse() -> Publishers.TryMap<Self, (data: Data, response: HTTPURLResponse)> {
        return self.tryMap { input in
            guard let response = input.response as? HTTPURLResponse else {
                throw Squid.Error.invalidResponse
            }
            return (data: input.data, response: response)
        }
    }
}

extension Publisher where Output == (data: Data, response: HTTPURLResponse) {

    // swiftlint:disable identifier_name
    fileprivate func debugResponse<R, N>(
        of request: R, withId id: N
    ) -> Publishers.HandleEvents<Self> where R: Request, N: Numeric {
        return self.handleEvents(receiveOutput: { result in
            Squid.Logger.shared.log(
                "Finished request `\(type(of: request))` with identifier \(id):\n" +
                result.response.description(for: result.data).indent(spaces: 4)
            )
        }, receiveCompletion: { completion in
            switch completion {
            case .failure(let error):
                Squid.Logger.shared.log(
                    "Finished request `\(type(of: request))` with identifier \(id):\n" +
                    "- Unknown error: \(error)".indent(spaces: 4)
                )
            default:
                return
            }
        })
    }

    typealias ValidationReturn = Publishers.MapError<Publishers.TryMap<Self, Data>, Squid.Error>

    fileprivate func validate(statusCodeIn range: CountableClosedRange<Int>) -> ValidationReturn {
        return self.tryMap { response -> Data in
            let statusCode = response.response.statusCode
            if !range.contains(statusCode) {
                throw Squid.Error.requestFailed(statusCode: statusCode, response: response.data)
            }
            return response.data
        }.mapError(Squid.Error.ensure) // no typed throws...
    }
}

extension Publisher where Output == Result<URLSessionWebSocketTask.Message, Squid.Error> {

    // swiftlint:disable identifier_name
    fileprivate func debugItem<R, N>(
        of request: R, withId id: N
    ) -> Publishers.HandleEvents<Self> where R: StreamRequest, N: Numeric {
        return self.handleEvents(receiveOutput: { result in
            switch result {
            case .success(let message):
                Squid.Logger.shared.log(
                    "Stream `\(type(of: request))` with identifier \(id) received message:\n" +
                    "- Message: \(message)".indent(spaces: 4)
                )
            case .failure(let error):
                Squid.Logger.shared.log(
                    "Stream `\(type(of: request))` with identifier \(id) received error:\n" +
                    "- Error: \(error)".indent(spaces: 4)
                )
            }
        }, receiveCompletion: { completion in
            switch completion {
            case .failure(let error):
                Squid.Logger.shared.log(
                    "Cancelled stream `\(type(of: request))` with identifier \(id):\n" +
                    "- Error: \(error)".indent(spaces: 4)
                )
            default:
                return
            }
        })
    }
}

extension Publisher where Output == HttpHeader, Failure == Squid.Error {

    fileprivate func attachToHttpRequest<R>(
        _ request: R, service: HttpService
    ) -> Publishers.FlatMap<UnsharedFuture<HttpRequest, Squid.Error>, Self> where R: Request {
        return self.flatMap { header -> UnsharedFuture<HttpRequest, Squid.Error> in
            return UnsharedFuture<HttpRequest, Squid.Error> { promise in
                // 1) Initialize request with destination URL
                guard var httpRequest = HttpRequest(url: service.apiUrl) else {
                    promise(.failure(.invalidUrl))
                    return
                }

                // 2) Modify request to carry all required data
                do {
                    httpRequest = try httpRequest
                        .with(scheme: request.usesSecureProtocol ? "https" : "http")
                        .with(method: request.method)
                        .with(route: request.routes)
                        .with(query: request.query)
                        .with(header: service.header + header + request.header)
                        .with(body: request.body)
                        .process(with: request.prepare(_:))
                } catch {
                    promise(.failure(.ensure(error)))
                }

                // 3) Validate request
                if let error = request.validate() {
                    promise(.failure(error))
                }

                promise(.success(httpRequest))
            }
        }
    }

    fileprivate func attachToStreamRequest<R>(
        _ request: R, service: HttpService
    ) -> Publishers.FlatMap<UnsharedFuture<HttpRequest, Squid.Error>, Self>
    where R: StreamRequest {
        return self.flatMap { header -> UnsharedFuture<HttpRequest, Squid.Error> in
            return UnsharedFuture<HttpRequest, Squid.Error> { promise in
                // 1.1) Initialize request with destination URL
                guard var httpRequest = HttpRequest(url: service.apiUrl) else {
                    promise(.failure(.invalidUrl))
                    return
                }

                // 1.2) Modify request to carry all required data
                do {
                    httpRequest = try httpRequest
                        .with(scheme: request.usesSecureProtocol ? "wss" : "ws")
                        .with(method: .get)
                        .with(route: request.routes)
                        .with(query: request.query)
                        .with(header: service.header + header + request.header)
                } catch {
                    promise(.failure(.ensure(error)))
                }

                promise(.success(httpRequest))
            }
        }
    }
}

extension HTTPURLResponse {

    fileprivate func description(for data: Data) -> String {
        let headerString = (self.allHeaderFields as? [String: String])?
            .httpHeaderDescription?.indent(spaces: 12, skipLines: 1)
        let jsonBody = data.prettyPrintedJson.map { "\n" + $0.indent(spaces: 12) }

        return """
        - Status:   \(self.statusCode)
        - Headers:  \(headerString ?? "<none>")
        - Body:     <\(data.count) bytes>\(jsonBody ?? "")
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
