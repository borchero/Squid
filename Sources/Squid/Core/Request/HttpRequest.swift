//
//  HttpRequest.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

internal struct HttpRequest {

    // MARK: Properties
    let urlRequest: URLRequest
    private let body: HttpBody?

    // MARK: Initialization
    init?(url: UrlConvertible) {
        guard let url = url.url else {
            return nil
        }
        self.urlRequest = URLRequest(url: url)
        self.body = nil
    }

    private init(_ request: URLRequest, _ body: HttpBody?) {
        self.urlRequest = request
        self.body = body
    }

    // MARK: Instance Methods
    func with(scheme: String) -> HttpRequest {
        var request = self.urlRequest
        request.url = request.url
            .map { scheme + "://" + $0.absoluteString.components(separatedBy: "://").last! }
            .flatMap(URL.init(string:))
        return HttpRequest(request, self.body)
    }

    func with(method: HttpMethod) -> HttpRequest {
        var request = self.urlRequest
        method.add(to: &request)
        return HttpRequest(request, self.body)
    }

    func with(route: HttpRoute) -> HttpRequest {
        var request = self.urlRequest
        route.add(to: &request)
        return HttpRequest(request, self.body)
    }

    func with(query: HttpQuery) throws -> HttpRequest {
        var request = self.urlRequest
        try query.add(to: &request)
        return HttpRequest(request, self.body)
    }

    func with(header: HttpHeader) throws -> HttpRequest {
        var request = self.urlRequest
        try header.add(to: &request)
        return HttpRequest(request, self.body)
    }

    func with(body: HttpBody) throws -> HttpRequest {
        var request = self.urlRequest
        try body.add(to: &request)
        return HttpRequest(request, body)
    }

    func process(with execute: (URLRequest) -> URLRequest) -> HttpRequest {
        let newRequest = execute(self.urlRequest)
        return HttpRequest(newRequest, self.body)
    }
}

/// :nodoc:
extension HttpRequest: CustomStringConvertible {

    var description: String {
        let headerString = self.urlRequest
            .allHTTPHeaderFields?.httpHeaderDescription?.indent(spaces: 12, skipLines: 1)

        return """
        - Method:   \(self.urlRequest.httpMethod ?? "<none>")
        - Url:      \(self.urlRequest.url?.absoluteString ?? "<none>")
        - Headers:  \(headerString ?? "<none>")
        - Body:     \(self.body?.description.indent(spaces: 12, skipLines: 1) ?? "<none>")
        """
    }
}
