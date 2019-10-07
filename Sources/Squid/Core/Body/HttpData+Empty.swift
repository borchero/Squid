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
        
        /// Initializes a new empty HTTP body. The initializer does nothing.
        public init() {
            // nothing to do here
        }
        
        public var description: String {
            return "<none>"
        }
        
        public func add(to request: inout URLRequest) throws {
            // nothing to do here
        }
    }
}
