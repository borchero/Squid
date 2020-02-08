//
//  FailureTests.swift
//  SquidTests
//
//  Created by Oliver Borchert on 2/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import XCTest
import OHHTTPStubs
@testable import Squid

final class FailureTests: XCTestCase {
    
    override func setUp() {
        HTTPStubs.removeAllStubs()
    }
    
    func test401() {
        StubFactory.shared.unauthorizedRequest()
        
        let expectation = XCTestExpectation()
        
        let service = MyApi()
        let request = AuthorizeRequest()
        let response = request.schedule(with: service)
        
        let c = response
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    switch error {
                    case .requestFailed(statusCode: 401, response: _):
                        expectation.fulfill()
                    default:
                        return
                    }
                default:
                    return
                }
            }, receiveValue: { _ in })
        
        wait(for: [expectation], timeout: 0.2)
        c.cancel()
    }
    
    func test404() {
        let expectation = XCTestExpectation()
    
        let service = My404Api()
        let request = UsersRequest()
        let response = request.schedule(with: service)
        
        let c = response.sink(receiveCompletion: { completion in
            if case .failure = completion {
                expectation.fulfill()
            }
        }) { _ in }
        
        wait(for: [expectation], timeout: 0.2)
        c.cancel()
    }
}
