//
//  HttpHeader.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

/// This struct is used to represent a header of HTTP requests. It can contain arbitrarily many
/// fields which are each defined by a key and a value. The key is of the type `HttpHeader.Field`.
/// The value always needs to be of type `String`.
public struct HttpHeader {

    // MARK: Inner Type
    /// A header field represents the *key* for a specific entry in the HTTP header. There exist
    /// some pre-defined header fields that are used frequently (e.g. Content-Type) which are
    /// exposed via static variables.
    /// The user may add additional static variables here to provide a safe way for using header
    /// fields.
    /// Header fields can also be (transparently) initialized via strings, i.e. anywhere where
    /// a header field is required, the user may simply pass a `String`. Nonetheless, the usage of
    /// static variables is encouraged to prevent needless typos.
    public struct Field {

        internal let name: String
    }

    // MARK: Properties
    private let fields: [Field: String]

    // MARK: Initialization
    /// Initializes a new header for a HTTP request with the given fields.
    ///
    /// - Parameter fields: A mapping from header fields (more precisely, keys) to values.
    public init(_ fields: [Field: String]) {
        self.fields = fields
    }

    // MARK: Instance Methods
    internal func add(to request: inout URLRequest) throws {
        for (key, value) in self.fields {
            let escaped = value.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            )
            guard let val = escaped else {
                throw Squid.Error.encodingFailed
            }
            request.addValue(val, forHTTPHeaderField: key.name)
        }
    }
}

extension HttpHeader: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (Field, String)...) {
        let dict = Dictionary(uniqueKeysWithValues: elements)
        self.init(dict)
    }
}

// MARK: Operators
extension HttpHeader {

    /// Combines the fields of two different headers into a single header containing all fields.
    /// Whenever a field occurs in both headers, the value of the second header is used.
    public static func + (lhs: Self, rhs: Self) -> Self {
        return HttpHeader(
            lhs.fields.merging(rhs.fields, uniquingKeysWith: { $1 })
        )
    }
}

// MARK: Header Fields
extension HttpHeader.Field {

    /// HTTP "Accept" header: defines a list of allowed media types in the response.
    public static let accept: HttpHeader.Field = "Accept"

    /// HTTP "Accept-Language" header: defines a list of allowed languages in the response.
    public static let acceptLanguage: HttpHeader.Field = "Accept-Language"

    /// HTTP "Authorization" header: authentication credentials for HTTP authentication.
    public static let authorization: HttpHeader.Field = "Authorization"

    /// HTTP "Content-Length" header: the length of the request body in bytes.
    public static let contentLength: HttpHeader.Field = "Content-Length"

    /// HTTP "Content-Type" header: the MIME type of the request body. Use `HttpMimeType` for
    /// defining values.
    public static let contentType: HttpHeader.Field = "Content-Type"

    /// Custom HTTP "X-Api-Key" header that is used often: sets an API key that identifies the
    /// application to the server.
    public static let apiKey: HttpHeader.Field = "X-Api-Key"
}

// MARK: Initialization
extension HttpHeader.Field: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self.name = value
    }
}

// MARK: Hashable
extension HttpHeader.Field: Hashable {

    public func hash(into hasher: inout Hasher) {
        self.name.hash(into: &hasher)
    }
}
