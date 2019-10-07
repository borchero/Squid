//
//  PaginatedRequest.swift
//  Squid
//
//  Created by Oliver Borchert on 10/4/19.
//

import Foundation

/// A paginated request describes a request which loads a large number of elements over multiple
/// requests, i.e. over several pages. A paginated request is a usual request which defines two
/// additional properties, namely `page` and `chunk`. These are used to load the elements
/// incrementally. Note that the only supported HTTP method is GET and no request body must
/// therefore be defined.
///
/// In addition to a simple request, the paginated request also requires the result type to conform
/// to the `PaginatedData` protocol. This enables automating requesting multiple pages on demand.
public protocol PaginatedRequest: Request where Result: PaginatedData {
    
    /// The index of the currently requested page.
    var page: Int { get }
    
    /// The (maximum) number of elements that are requested. The number of returned elements is only
    /// smaller than the given chunk if the given page index is the index of the last page and the
    /// number of elements is not divisible by the chunk size.
    var chunk: Int { get }
}

/// A paginated JSON request is equivalent to the `PaginatedRequest`. The only difference is the
/// requirement that the result type is `Decodable`.
public protocol PaginatedJsonRequest: PaginatedRequest where Result: Decodable {
    
    /// Defines whether the decoder decoding the raw data to the result type should consider
    /// camel case in the Swift code as snake case in the JSON (i.e. `userID` would be parsed from
    /// the field `user_id` if not specified explicity in the type to decode to). By default,
    /// attributes are decoded using snake case attribute names.
    var decodeSnakeCase: Bool { get }
}

extension PaginatedJsonRequest {
    
    public var decodeSnakeCase: Bool {
        return true
    }
    
    public func decode(_ data: Data) throws -> Result {
        let decoder = JSONDecoder()
        if self.decodeSnakeCase {
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        }
        return try decoder.decode(Result.self, from: data)
    }
}
