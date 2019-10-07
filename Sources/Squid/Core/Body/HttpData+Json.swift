//
//  HttpData+Json.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

extension HttpData {
    
    /// The JSON HTTP body is presumably the most commonly used non-empty body for HTTP requests.
    /// It encodes an encodable type as JSON and sets the body of an HTTP request as well as the
    /// "Content-Type" header to "application/json".
    public struct Json<T>: HttpBody where T: Encodable {
        
        // MARK: Properties
        private let value: T
        private let encoder: JSONEncoder
        
        // MARK: Initialization
        /// Initializes a new JSON HTTP body which ought to encode the given value in the request
        /// body.
        ///
        /// - Parameter value: The value to put into the request body.
        /// - Parameter encoder: The JSON encoder to use for encoding. By default, a JSON encoder is
        ///                      used where camel case attribute names are converted into snake
        ///                      case (see `snakeCaseJSONEncoder`).
        public init(_ value: T, encoder: JSONEncoder = snakeCaseJSONEncoder()) {
            self.value = value
            self.encoder = encoder
        }
        
        // MARK: Instance Methods
        public func add(to request: inout URLRequest) throws {
            request.addValue(
                HttpMimeType.json.rawValue, forHTTPHeaderField: "Content-Type"
            )
            do {
                request.httpBody = try self.encoder.encode(self.value)
            } catch {
                throw Squid.Error.encodingFailed
            }
        }
    }
}

extension HttpData.Json {
    
    public var description: String {
        let debugEncoder = JSONEncoder()
        debugEncoder.outputFormatting = .prettyPrinted
        return String(
            data: (try? debugEncoder.encode(self.value)) ?? Data(),
            encoding: .utf8
        ) ?? ""
    }
}

/// Returns a JSON encoder that converts camel case attribute names to snake case. You should not
/// use this function directly as it may be removed in the future. It is only declared as public to
/// be used as default value in the initializer of `HttpData.Json`.
public func snakeCaseJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
}
