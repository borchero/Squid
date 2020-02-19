//
//  HttpData+Image.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

extension HttpData {

    /// The image HTTP body can be used to attach an image to a request. Currently, only PNG and
    /// JPEG images are supported. When adding the image's data to the body of the request, this
    /// body also sets the "Content-Type" header to the appropriate MIME type as well as the
    /// "Content-Length" header to the size of the image in bytes.
    public struct Image: HttpBody {

        let mime: HttpMimeType
        let data: Data

        // MARK: Initialization
        /// Initializes a new HTTP image body.
        ///
        /// - Parameter mime: The MIME type of the image, i.e. of the given data.
        /// - Parameter data: The image's data to set as the request's body.
        public init(_ mime: HttpMimeType, data: Data) {
            self.mime = mime
            self.data = data
        }

        // MARK: HttpBody
        public func add(to request: inout URLRequest) throws {
            request.addValue(
                self.mime.rawValue,
                forHTTPHeaderField: HttpHeader.Field.contentType.name
            )
            request.addValue(
                String(describing: self.data.count),
                forHTTPHeaderField: HttpHeader.Field.contentLength.name
            )
            request.httpBody = self.data
        }
    }
}

extension HttpData.Image {

    // MARK: CustomStringConvertible
    public var description: String {
        return "<binary data of size \(self.data.count)>"
    }
}
