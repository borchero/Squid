//
//  ServiceHookTests.swift
//  SquidTests
//
//  Created by Oliver Borchert on 3/17/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import XCTest
import OHHTTPStubs
import OHHTTPStubsSwift
import Combine
@testable import Squid

final class ServiceHookTests: XCTestCase {

    override func setUp() {
        HTTPStubs.removeAllStubs()
    }

    func testCachingHook() {
        StubFactory.shared.usersGet()

        // 1) Make valid request
        let exp1 = XCTestExpectation()

        let api = MyCachingApi()
        let request = UsersRequest()

        let c1 = request.schedule(with: api).ignoreError()
            .sink { _ in
                exp1.fulfill()
            }

        wait(for: [exp1], timeout: 0.1)
        c1.cancel()

        // 2) Make failing request and force cache usage
        HTTPStubs.removeAllStubs()
        let exp2 = XCTestExpectation()

        let c2 = request.schedule(with: api).ignoreError()
            .sink { users in
                XCTAssertEqual(users.count, 2)
                exp2.fulfill()
            }

        wait(for: [exp2], timeout: 0.1)
        c2.cancel()
    }
}
