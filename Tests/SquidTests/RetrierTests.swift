//
//  RetrierTests.swift
//  SquidTests
//
//  Created by Oliver Borchert on 2/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import XCTest
import OHHTTPStubs
@testable import Squid

final class RetrierTests: XCTestCase {
    
    override func setUp() {
        HTTPStubs.removeAllStubs()
    }
    
    func testBackoffRetrier() {
        RetrierStubFactory.shared.throttleRoute()
        RetrierStubFactory.shared.setThrottling(true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            RetrierStubFactory.shared.setThrottling(false)
        }
        
        let expectation = XCTestExpectation()
        let service = MyRetryingApi()
        let request = ThrottledRequest()
        let cancellable = request.schedule(with: service).ignoreError()
            .sink { _ in
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 33)
        cancellable.cancel()
    }
    
    func testTokenRefreshRetrier() {
        RetrierStubFactory.shared.protectedRoute()
        RetrierStubFactory.shared.tokenRoute()
        
        let expectation = XCTestExpectation()
        
        let store = MyStore()
        let auth = MyAuthApi(store: store)
        let api = MyProtectedApi(auth: auth)
        
        let request = ProtectedRequest()
        let c = request.schedule(with: api).ignoreError().sink { _ in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3)
        c.cancel()
    }

    func testAsynchronousToken() {
        RetrierStubFactory.shared.protectedRoute()

        let expectation = XCTestExpectation()

        let api = MyAsyncProtectedApi()

        let request = ProtectedRequest()
        let c = request.schedule(with: api).ignoreError().sink { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        c.cancel()
    }
}
