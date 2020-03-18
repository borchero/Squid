//
//  HttpRoute.swift
//  SquidTests
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation

/// An HTTP route represents a set of URL routing paths. Essentially, a set of routing paths can
/// simply be represented by an array of strings. However, this entity enables initializing HTTP
/// routes without having to explicitly convert all path components to `String`.
public struct HttpRoute {

    private let paths: [String]

    // MARK: Initialization
    /// Initializes a new HTTP route.
    ///
    /// - Parameter parameters: The HTTP routing paths. All paths are converted to strings using
    ///                         the `String.init(describing:)` initializer.
    public init(_ paths: [Any]) {
        self.paths = paths.map(String.init(describing:))
    }

    internal func add(to request: inout URLRequest) {
        self.paths.forEach { route in
            request.url?.appendPathComponent(route)
        }
    }
}

// MARK: Protocol Conformance
extension HttpRoute: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension HttpRoute: Equatable {

    public static func == (lhs: HttpRoute, rhs: HttpRoute) -> Bool {
        return lhs.paths == rhs.paths
    }
}

extension HttpRoute: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.paths)
    }
}

// MARK: Operators
extension HttpRoute {

    /// Combines the routing paths of two HTTP routes by appending the paths of the latter route to
    /// the paths of the former route.
    public static func + (lhs: HttpRoute, rhs: HttpRoute) -> HttpRoute {
        return .init(lhs.paths + rhs.paths)
    }
}
