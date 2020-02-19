//
//  Http.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

/// This enum represents available HTTP methods for requests sent via the Squid library. Currently,
/// only the default REST methods are supported. Namely GET, POST, PUT, and DELETE.
public enum HttpMethod {

    /// GET method.
    case get

    /// POST method.
    case post

    /// PUT method.
    case put

    /// DELETE method.
    case delete

    internal var name: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .put: return "PUT"
        case .delete: return "DELETE"
        }
    }

    internal func add(to request: inout URLRequest) {
        request.httpMethod = self.name
    }
}
