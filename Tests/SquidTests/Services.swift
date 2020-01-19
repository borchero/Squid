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
        return "squid.borchero.com"
    }
}

struct My404Api: HttpService {
    
    var apiUrl: UrlConvertible {
        return "xxx.yyy.zzz"
    }
}

struct MyRetryingApi: HttpService {
    
    var apiUrl: UrlConvertible {
        return "squid.borchero.com"
    }
    
    var retrierFactory: RetrierFactory {
        return BackoffRetrier.factory()
    }
}
