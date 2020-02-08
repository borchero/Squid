//
//  RetrierStub.swift
//  SquidTests
//
//  Created by Oliver Borchert on 2/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Squid

class RetrierStubFactory {
    
    private static let token = "mytoken"
    
    internal static let shared = RetrierStubFactory()
    
    private let isThrottled = Locked(true)
    
    private init() { }
    
    func setThrottling(_ throttle: Bool) {
        self.isThrottled.value = throttle
    }
    
    func throttleRoute() {
        stub(
            condition: isHost("squid.borchero.com") && isMethodGET() && isPath("/throttle")
        ) { _ -> HTTPStubsResponse in
            if self.isThrottled.value {
                return .init(data: Data(), statusCode: 429, headers: [:])
            }
            return .init(data: Data(), statusCode: 204, headers: [:])
        }
    }
    
    func tokenRoute() {
        stub(
            condition: isHost("squid.borchero.com") && isMethodGET() && isPath("/token")
        ) { _ -> HTTPStubsResponse in
            let data = RetrierStubFactory.token.data(using: .utf8)!
            return .init(data: data, statusCode: 200, headers: [:])
        }
    }
    
    func protectedRoute() {
        stub(
            condition: isHost("squid.borchero.com") && isMethodGET() && isPath("/protected")
        ) { request -> HTTPStubsResponse in
            if request.allHTTPHeaderFields?["Authorization"] == RetrierStubFactory.token {
                return .init(data: Data(), statusCode: 204, headers: [:])
            }
            return .init(data: Data(), statusCode: 401, headers: [:])
        }
    }
}
