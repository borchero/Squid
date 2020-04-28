//
//  ErrorMapping.swift
//  SquidTests
//
//  Created by Oliver Borchert on 4/28/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import Foundation
import Squid

enum MyError: Error {
    case notFound
    case unknown
}

struct ErrorMappingApi: HttpService {

    var apiUrl: UrlConvertible {
        return "squid.borchero.com"
    }

    func mapError(_ error: Squid.Error) -> MyError {
        if case .requestFailed(statusCode: 404, response: _) = error {
            return .notFound
        }
        return .unknown
    }
}
