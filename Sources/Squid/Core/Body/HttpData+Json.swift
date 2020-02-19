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

        private let value: T
        private let encoder: JSONEncoder

        // MARK: Initialization
        /// Initializes a new JSON HTTP body which ought to encode the given value in the request
        /// body.
        ///
        /// - Parameter value: The value to put into the request body.
        /// - Parameter encoder: The JSON encoder to use for encoding. When set to `nil`, a JSON
        ///                      encoder is used where camel case attribute names are converted into
        ///                      snake case.
        public init(_ value: T, encoder: JSONEncoder? = nil) {
            self.value = value
            self.encoder = encoder ?? snakeCaseJSONEncoder()
        }

        // MARK: HttpBody
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

    // MARK: CustomStringConvertible
    public var description: String {
        let outputFormatting = self.encoder.outputFormatting

        self.encoder.outputFormatting = .prettyPrinted

        let result = String(
            data: (try? self.encoder.encode(self.value)) ?? Data(),
            encoding: .utf8
        ) ?? ""

        self.encoder.outputFormatting = outputFormatting

        return result
    }
}

private func snakeCaseJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
}
