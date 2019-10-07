//
//  PaginatedData.swift
//  Squid
//
//  Created by Oliver Borchert on 10/4/19.
//

import Foundation

public protocol PaginatedData {
    
    associatedtype Data
    
    var data: Data { get }
    
    var page: Int { get }
    var from: Int { get }
    var to: Int { get }
    var chunk: Int { get }
    
    var totalCount: Int { get }
    var totalPageCount: Int { get }
}

extension PaginatedData {
    
    public var count: Int {
        return self.from - self.to
    }
    
    public var isLastPage: Bool {
        return self.page == self.totalPageCount
    }
}
