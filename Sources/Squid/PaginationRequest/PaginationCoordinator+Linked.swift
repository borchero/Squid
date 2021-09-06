//
//  PaginationCoordinator+Linked.swift
//  Squid
//
//  Created by Andreas Pfurtscheller on 9/4/21
//

import Foundation

public struct LinkedPaginationCoordinator<R: Request, D: LinkedPaginatedData>: PaginationCoordinator
where R.Result == D.DataType {

    public typealias BaseRequest = R

    public typealias PaginationType = D

    public typealias PaginatedRequest = LinkedPaginationRequest<R, D>
    
    public init() {}

    public func pageRequest(
        from baseRequest: R,
        pointer: PaginationPointer,
        previousData: D?
    ) -> LinkedPaginationRequest<BaseRequest, PaginationType> {
        LinkedPaginationRequest(
            base: baseRequest,
            pageUrl: previousData.flatMap({ pointer == .next ? $0.nextPageUrl : $0.previousPageUrl })
        )
    }
}

public protocol LinkedPaginatedData: PaginatedData {

    // MARK: Page Metadata

    var previousPageUrl: URL? { get }

    var nextPageUrl: URL? { get }

}

extension LinkedPaginatedData {

    /// Returns whether the returned page of the data is the last page available.
    public var isLastPage: Bool {
        nextPageUrl == nil
    }
}

public struct LinkedPaginationRequest<BaseRequest, Result>: Request
where Result: PaginatedData, BaseRequest: Request, BaseRequest.Result == Result.DataType {

    private let base: BaseRequest
    private let pageUrl: URL?

    init(
        base: BaseRequest,
        pageUrl: URL?
    ) {
        self.base = base
        self.pageUrl = pageUrl
    }

    public var method: HttpMethod {
        return .get
    }

    public var url: UrlConvertible? {
        return pageUrl
    }

    public var header: HttpHeader {
        return self.base.header
    }

    public var query: HttpQuery {
        return HttpQuery()
    }

    public var body: HttpBody {
        return HttpData.Empty()
    }

    public var acceptedStatusCodes: CountableClosedRange<Int> {
        return self.base.acceptedStatusCodes
    }

    public var priority: RequestPriority {
        return self.base.priority
    }

    public func decode(_ data: Data) throws -> Result {
        return try Result.init(data: data)
    }
}
