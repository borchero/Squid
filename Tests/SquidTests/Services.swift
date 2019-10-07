//
//  Services.swift
//  Squid
//
//  Created by Oliver Borchert on 10/6/19.
//

import Foundation
@testable import Squid

struct MyApi: HttpService {
    
    var apiUrl: UrlConvertible {
        return "https://squid.borchero.com"
    }
}

struct MyRetryingApi: HttpService {
    
    var apiUrl: UrlConvertible {
        return "https://squid.borchero.com"
    }
    
    var retrierFactory: RetrierFactory {
        return BackoffRetrier.factory()
    }
}
