//
//  PaginatedRequest.swift
//  Squid
//
//  Created by Oliver Borchert on 10/4/19.
//

import Foundation

public protocol PaginatedRequest: Request where Result: PaginatedData {
    
    associatedtype Base: Request where Base.Result == Result.Data
    
    var base: Base { get }
    var page: Int { get }
    var chunk: Int { get }
}

extension PaginatedRequest {
    
    public var method: HttpMethod {
        assert(self.base.method == .get, "Paginated request must use HTTP method GET.")
        return self.base.method
    }
    
    public var routingPaths: [String] {
        return self.base.routingPaths
    }
    
    public var header: HttpHeader {
        return self.base.header
    }
    
    public var query: HttpQuery {
        let query = self.base.query
        return query + ["page": self.page, "chunk": self.chunk]
    }
    
    public var body: HttpBody {
        assert(self.base.body is HttpData.Empty, "Paginated request must not have an HTTP body.")
        return self.base.body
    }
    
    public var acceptedStatusCodes: CountableClosedRange<Int> {
        return self.base.acceptedStatusCodes
    }
    
    public var priority: RequestPriority {
        return self.base.priority
    }
}

public protocol PaginatedJsonRequest: JsonRequest where Result: PaginatedData {
    
    
}
