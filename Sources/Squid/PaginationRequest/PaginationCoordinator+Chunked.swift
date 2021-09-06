//
//  PaginationCoordinator+Chunked.swift
//  Squid
//
//  Created by Andreas Pfurtscheller on 9/4/21
//

import Foundation

public struct ChunkedPaginationCoordinator<R: Request, D: ChunkedPaginatedData>: PaginationCoordinator
where R.Result == D.DataType {
    
    public typealias BaseRequest = R

    public typealias PaginationType = D

    public typealias PaginatedRequest = ChunkedPaginationRequest<R, D>

    public let chunk: Int
    public let zeroBasedPageIndex: Bool

    public init(chunk: Int, zeroBasedPageIndex: Bool) {
        self.chunk = chunk
        self.zeroBasedPageIndex = zeroBasedPageIndex
    }
    
    public func pageRequest(
        from baseRequest: R,
        pointer: PaginationPointer,
        previousData: D?
    ) -> ChunkedPaginationRequest<BaseRequest, PaginationType> {
        ChunkedPaginationRequest(
            base: baseRequest,
            page: previousData.map({ $0.page + 1 }) ?? (zeroBasedPageIndex ? 0 : 1),
            chunk: chunk
        )
    }
}

public protocol ChunkedPaginatedData: PaginatedData {

    // MARK: Page Metadata
    /// The index of the current page. By convention, an index of 1 indicates the first page. You
    /// will need to overwrite the `zeroBasedPageIndex` property to return `true` when you want to
    /// use an API where the first page has index 0.
    var page: Int { get }

    /// The index of the first element of the data (inclusive).
    var from: Int { get }

    // swiftlint:disable identifier_name
    /// The index of the last element of the data (exclusive).
    var to: Int { get }

    /// The requested number of items on the page. Might be larger than the actual number of
    /// elements.
    var chunk: Int { get }

    /// The total number of elements that are available.
    var totalCount: Int { get }

    /// The total number of pages that are available given the chunk.
    var totalPageCount: Int { get }

    /// Whether the first page of the paginated request is indexed with 0. By default, this property
    /// is `false` and indicates that the first page is indexed with 1.
    var zeroBasedPageIndex: Bool { get }

}

extension ChunkedPaginatedData {

    public var zeroBasedPageIndex: Bool {
        return false
    }

    // MARK: Synthesized Properties
    /// The number of elements currently returned.
    public var count: Int {
        return self.from - self.to
    }

    /// Returns whether the returned page of the data is the last page available.
    public var isLastPage: Bool {
        if self.zeroBasedPageIndex {
            return self.page == self.totalPageCount - 1
        }
        return self.page == self.totalPageCount
    }
}

public struct ChunkedPaginationRequest<BaseRequest, Result>: Request
where Result: PaginatedData, BaseRequest: Request, BaseRequest.Result == Result.DataType {

    private let base: BaseRequest
    private let page: Int
    private let chunk: Int

    init(
        base: BaseRequest,
        page: Int,
        chunk: Int
    ) {
        self.base = base
        self.page = page
        self.chunk = chunk
    }

    public var method: HttpMethod {
        return .get
    }

    public var routes: HttpRoute {
        return self.base.routes
    }

    public var header: HttpHeader {
        return self.base.header
    }

    public var query: HttpQuery {
        return self.base.query + ["page": self.page, "chunk": self.chunk]
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
