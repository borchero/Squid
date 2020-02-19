//
//  HttpQuery.swift
//  Squid
//
//  Created by Oliver Borchert on 10/1/19.
//

import Foundation

/// This entity represents a set of HTTP query parameters. Basically, it abstracts a simple mapping
/// from keys (`String`) to values (`String`). As a result, an instance of this struct can also be
/// created directly from a `[String: Any]` dictionary literal where all values are represented in
/// the query parameters by calling `String.init(describing:)`.
public struct HttpQuery {

    // MARK: Properties
    let parameters: [String: String]

    // MARK: Initialization
    /// Initializes a new set of HTTP query parameters.
    ///
    /// - Parameter parameters: The mapping from keys to values. The latter are mapped to `String`
    ///                         via the `String.init(describing:)` initializer.
    public init(_ parameters: [String: Any] = [:]) {
        self.parameters = parameters.mapValues(String.init(describing:))
    }

    // MARK: Instance Methods
    internal func add(to request: inout URLRequest) throws {
        guard !self.parameters.isEmpty else {
            return
        }
        guard let requestUrl = request.url else {
            throw Squid.Error.encodingFailed
        }

        let comp = URLComponents(
            url: requestUrl, resolvingAgainstBaseURL: true
        )

        guard var components = comp else {
            throw Squid.Error.encodingFailed
        }
        components.queryItems = self.parameters.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }

        guard let url = components.url else {
            throw Squid.Error.encodingFailed
        }
        request.url = url
    }
}

extension HttpQuery: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, Any)...) {
        let dict = Dictionary(uniqueKeysWithValues: elements)
        self.init(dict)
    }
}

// MARK: Operators
extension HttpQuery {

    /// Combines the parameters of two queries into a single set of query parameters. Whenever a
    /// parameters occurs in both queries, the value of the second query is used.
    public static func + (lhs: Self, rhs: Self) -> Self {
        return HttpQuery(
            lhs.parameters.merging(rhs.parameters, uniquingKeysWith: { $1 })
        )
    }
}
