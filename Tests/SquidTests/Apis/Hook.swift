//
//  Hook.swift
//  SquidTests
//
//  Created by Oliver Borchert on 3/17/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import Foundation
@testable import Squid

struct MyCachingApi: HttpService {

    let hook: ServiceHook = CachingServiceHook()

    var apiUrl: UrlConvertible {
        return "squid.borchero.com"
    }
}
