//
//  HttpData+Empty.swift
//  Squid
//
//  Created by Oliver Borchert on 10/1/19.
//

import Foundation

extension HttpData {

    /// The empty HTTP body is used as default for all requests and sets no HTTP body at all.
    public struct Empty: HttpBody {

        // MARK: Initialization
        /// Initializes a new empty HTTP body. The initializer does nothing.
        public init() {
            // nothing to do here
        }

        // MARK: HttpBody
        public func add(to request: inout URLRequest) throws {
            // nothing to do here
        }
    }
}

extension HttpData.Empty {

    // MARK: CustomStringConvertible
    public var description: String {
        return "<none>"
    }
}
