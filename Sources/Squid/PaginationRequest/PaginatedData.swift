//
//  PaginatedData.swift
//  Squid
//
//  Created by Oliver Borchert on 10/4/19.
//

import Foundation

/// The paginated data protocol defines a common interface for result types of paginated requests.
/// The properties of the protocol can be leveraged to enable handling paginated requests
/// automatically by observing the provided properties.
public protocol PaginatedData {

    // MARK: Data
    /// The actual type of the requested data (usually provided as a field of the top-level JSON).
    associatedtype DataType

    /// The actual data that is received by the request.
    var data: DataType { get }

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

extension PaginatedData {

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
