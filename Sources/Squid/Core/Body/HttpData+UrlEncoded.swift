//
//  HttpData+UrlEncoded.swift
//  Squid
//
//  Created by Andreas Pfurtscheller on 9/17/19.
//

import Foundation

extension HttpData {

    /// The urlencoded HTTP body adds the urlcomponents to the request and
    /// sets the "Content-Type" header to "application/x-www-form-urlencoded".
    public struct Urlencoded: HttpBody {

        /// Configures how `Array` parameters are encoded.
        // swiftlint:disable nesting
        public enum ArrayEncoding {
            /// An empty set of square brackets is appended to the key for every value. This is the default behavior.
            case brackets
            /// No brackets are appended. The key is encoded as is.
            case noBrackets

            func encode(key: String) -> String {
                switch self {
                case .brackets:
                    return "\(key)[]"
                case .noBrackets:
                    return key
                }
            }
        }

        /// Configures how `Bool` parameters are encoded.
        // swiftlint:disable nesting
        public enum BoolEncoding {
            /// Encode `true` as `1` and `false` as `0`. This is the default behavior.
            case numeric
            /// Encode `true` and `false` as string literals.
            case literal

            func encode(value: Bool) -> String {
                switch self {
                case .numeric:
                    return value ? "1" : "0"
                case .literal:
                    return value ? "true" : "false"
                }
            }
        }

        /// The dictionary of query items  to apply to the `URLRequest`.
        private let queryItems: [String: Any]

        /// The encoding to use for `Array` parameters.
        public let arrayEncoding: ArrayEncoding

        /// The encoding to use for `Bool` parameters.
        public let boolEncoding: BoolEncoding

        // MARK: Initialization
        /// Initializes a new urlencoded HTTP body which ought to add the given value to the request
        /// body.
        ///
        /// - Parameters:
        ///   - queryItems: The query items to put into the request body.
        ///   - arrayEncoding: `ArrayEncoding` to use. `.brackets` by default.
        ///   - boolEncoding: `BoolEncoding` to use. `.numeric` by default.
        public init(
            _ queryItems: [String: Any],
            arrayEncoding: ArrayEncoding = .brackets,
            boolEncoding: BoolEncoding = .numeric
        ) {
            self.queryItems = queryItems
            self.arrayEncoding = arrayEncoding
            self.boolEncoding = boolEncoding
        }

        // MARK: HttpBody
        public func add(to request: inout URLRequest) throws {

            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.addValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "Content-Type"
                )
            }

            request.httpBody = components.query?.data(using: .utf8)
        }

        fileprivate var components: URLComponents {
            var components = URLComponents()
            components.queryItems = encodeQuery(queryItems)
            return components
        }

        private func encodeQuery(_ items: [String: Any]) -> [URLQueryItem] {
            return items.sorted(by: { $0.0 < $1.0 }).flatMap({ encodeQueryItems(key: $0.key, value: $0.value) })
        }

        private func encodeQueryItems(key: String, value: Any) -> [URLQueryItem] {
            switch value {
            case let dictionary as [String: Any]:
                return dictionary.flatMap({ encodeQueryItems(key: "\(key)[\($0.key)]", value: $0.value) })
            case let array as [Any]:
                return array.flatMap({ encodeQueryItems(key: arrayEncoding.encode(key: key), value: $0) })
            case let number as NSNumber:
                return [encodeQueryItem(key: key, value: (
                    number.isBool ? boolEncoding.encode(value: number.boolValue) : "\(number)"
                ))]
            case let bool as Bool:
                return [encodeQueryItem(key: key, value: boolEncoding.encode(value: bool))]
            default:
                return [encodeQueryItem(key: key, value: "\(value)")]
            }
        }

        private func encodeQueryItem(key: String, value: String) -> URLQueryItem {
            return URLQueryItem(name: escape(key), value: escape(value))
        }

        private func escape(_ string: String) -> String {
            return string.addingPercentEncoding(withAllowedCharacters: .squidURLQueryAllowed) ?? string
        }
    }
}

extension HttpData.Urlencoded {

    public var description: String {
        return components.query ?? ""
    }
}

extension HttpData.Urlencoded: Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.components == rhs.components
    }
}

extension HttpData.Urlencoded: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.components)
    }
}

extension HttpData.Urlencoded: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, Any)...) {
        self.init(elements.reduce(into: [:]) { result, element in
            result[element.0] = element.1
        })
    }
}

extension CharacterSet {

    /// Creates a CharacterSet from RFC 3986 allowed characters.
    ///
    /// RFC 3986 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    fileprivate static let squidURLQueryAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()
}

extension NSNumber {

    fileprivate var isBool: Bool {
        // Use Obj-C type encoding to check whether the underlying type is a `Bool`,
        // as it's guaranteed as part of swift-corelibs-foundation.
        String(cString: objCType) == "c"
    }
}
