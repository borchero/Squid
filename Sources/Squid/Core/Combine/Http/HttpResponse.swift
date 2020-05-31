//
//  HttpResponse.swift
//  Squid
//
//  Created by Oliver Borchert on 5/31/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import Foundation

internal struct RawHttpResponse {

    let base: HTTPURLResponse
    let body: Data

    var header: [String: String] {
        return .init(uniqueKeysWithValues: self.base.allHeaderFields.compactMap { element in
            guard let key = element.key as? String, let value = element.value as? String else {
                return nil
            }
            return (key, value)
        })
    }

    func decode<Body>(using closure: (Data) throws -> Body) rethrows -> HttpResponse<Body> {
        let body = try closure(self.body)
        return HttpResponse(body: body, header: self.header)
    }
}

internal struct HttpResponse<Body> {

    let body: Body
    let header: [String: String]
}
