//
//  HttpBody.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

/// The HttpData enum is an empty enumeration that is merely used to put different implementations
/// of `HttpBody` into a common scope. Out of the box, Squid provides `HttpData.Empty`,
/// `HttpData.Json` and `HttpData.Image` which all implement the `HttpBody` protocol.
public enum HttpData {

}

/// The HttpBody protocol ought to be implemented by any entity that can attach data to the body of
/// an HTTP request. Any entities implementing this protocol should be scoped in an extension of the
/// `HttpData` enum.
public protocol HttpBody: CustomStringConvertible {

    /// Adds the body to the given request. The method also adds appropriate headers based on the
    /// HTTP body.
    ///
    /// - Parameter request: The request to add the body to.
    func add(to request: inout URLRequest) throws
}

extension HttpBody {

    /// The description is used for debugging purposes: whenever requests are printed, their body's
    /// description is printed.
    public var description: String {
        return "Kind <\(type(of: self))>"
    }
}
