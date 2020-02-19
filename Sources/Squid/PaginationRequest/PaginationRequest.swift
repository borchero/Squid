//
//  PaginationRequest.swift
//  Squid
//
//  Created by Oliver Borchert on 10/4/19.
//

import Foundation

internal struct PaginationRequest<Base, Result>: Request
where Base: Request, Result: PaginatedData, Base.Result == Result.DataType {

    private let base: Base
    private let page: Int
    private let chunk: Int
    private let _decode: (Data, Base) throws -> Result

    init(base: Base, page: Int, chunk: Int, decode: @escaping (Data, Base) throws -> Result) {
        self.base = base
        self.page = page
        self.chunk = chunk
        self._decode = decode
    }

    var method: HttpMethod {
        return .get
    }

    var routes: HttpRoute {
        return self.base.routes
    }

    var header: HttpHeader {
        return self.base.header
    }

    var query: HttpQuery {
        return self.base.query + ["page": self.page, "chunk": self.chunk]
    }

    var body: HttpBody {
        return HttpData.Empty()
    }

    var acceptedStatusCodes: CountableClosedRange<Int> {
        return self.base.acceptedStatusCodes
    }

    var priority: RequestPriority {
        return self.base.priority
    }

    func decode(_ data: Data) throws -> Result {
        return try self._decode(data, self.base)
    }
}
