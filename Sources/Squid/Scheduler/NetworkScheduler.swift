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
    @Atomic private var runningIdentifier: Int = 0
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
    
    // MARK: Instance Methods
    func schedule<R>(_ request: R, service: HttpService) -> Response<R> where R: Request {
        #if DEBUG
        let requestId = self._runningIdentifier++
        #endif
        
        // 1) Build HTTP request
        let httpRequest = Future<HttpRequest, Squid.Error> { promise in
            // 1.1) Initialize request with destination URL
            guard var httpRequest = HttpRequest(url: service.apiUrl) else {
                promise(.failure(.invalidUrl))
                return
            }
            
            // 1.2) Validate request
            if let error = request.validate() {
                promise(.failure(error))
            }
            
            // 1.3) Modify request to carry all required data
            do {
                httpRequest = try httpRequest
                    .with(method: request.method)
                    .with(route: request.routes)
                    .with(query: request.query)
                    .with(header: service.header + request.header)
                    .with(body: request.body)
            } catch let error as Squid.Error {
                promise(.failure(error))
            } catch {
                promise(.failure(.unknown(error)))
            }
            
            promise(.success(httpRequest))
        }
        
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
            .print()
        
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
        
        // 7) Dispatch onto background thread depending on priority
        let dispatchedResponse = decodedResponse
            .subscribe(on: self.queues[request.priority]!)
        
        return Response(publisher: dispatchedResponse, request: request)
    }
    
    // MARK: Private Methods
    private func getSession(for configuration: URLSessionConfiguration) -> URLSession {
        if let session = self.sessions[configuration] {
            return session
        }
        let session = URLSession(
            configuration: configuration,
            delegate: URLSessionDelegateProxy.shared,
            delegateQueue: nil
        )
        self.sessions[configuration] = session
        return session
    }
}

// MARK: Extensions
extension Publisher where Output == HttpRequest {
    
    func debug<R>(request: R, withId id: Int) -> Publishers.HandleEvents<Self> where R: Request {
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
    
    fileprivate func debugResponse<R>(
        of request: R, withId id: Int
    ) -> Publishers.HandleEvents<Self> where R: Request {
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
    
    // TODO: Use `some Publisher` as soon as opaque return types are more powerful
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
