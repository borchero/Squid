//
//  PaginationCoordinator.swift
//  Squid
//
//  Created by Oliver Borchert on 10/4/19.
//

import Foundation

public protocol PaginationCoordinator
where PaginatedRequest.Result == PaginationType, BaseRequest.Result == PaginatedRequest.Result.DataType {

    associatedtype PaginationType: PaginatedData

    associatedtype BaseRequest: Request

    associatedtype PaginatedRequest: Request

    func pageRequest(
        from baseRequest: BaseRequest,
        pointer: PaginationPointer,
        previousData: PaginationType?
    ) -> PaginatedRequest
}

/// The paginated data protocol defines a common interface for result types of paginated requests.
/// The properties of the protocol can be leveraged to enable handling paginated requests
/// automatically by observing the provided properties.
public protocol PaginatedData {

    // MARK: Data
    /// The actual type of the requested data (usually provided as a field of the top-level JSON).
    associatedtype DataType

    init(data: Data) throws

    /// The actual data that is received by the request.
    var data: DataType { get }

    var isLastPage: Bool { get }
}

extension PaginatedData where Self: Decodable {

    init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }

}
