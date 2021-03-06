//
//  SquidTests.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import XCTest
import OHHTTPStubs
import OHHTTPStubsSwift
import Combine
@testable import Squid

final class SquidRequestTests: XCTestCase {
    
    override func setUp() {
        HTTPStubs.removeAllStubs()
    }
    
    func testAnyRequest() {
        StubFactory.shared.usersGet()
        
        Squid.Logger.silence(true)
        let expectation = XCTestExpectation()
        
        let request = AnyRequest(url: "squid.borchero.com/users")
        let response = request.schedule()

        let task = response
            .decode(type: [UserContainer].self, decoder: JSONDecoder())
            .ignoreError()
            .sink { users in
                XCTAssertEqual(users.count, 2)
                XCTAssertEqual(users[0].id, 0)
                XCTAssertEqual(users[0].firstname, "John")
                XCTAssertEqual(users[1].lastname, "Mustermann")
                expectation.fulfill()
            }
        let c = response.header
            .ignoreError()
            .sink { header in
                XCTAssertEqual(header["Content-Length"], "179")
                XCTAssertEqual(header["Content-Type"], "application/json")
            }
        
        wait(for: [expectation], timeout: 0.1)
        task.cancel()
        c.cancel()
        Squid.Logger.silence(false)
    }
    
    func testRequest() {
        StubFactory.shared.usersGet()
        
        let expectation = XCTestExpectation()

        let service = MyApi()
        let request = UsersRequest()
        let c = request.schedule(with: service).ignoreError()
            .sink { users in
                XCTAssertEqual(users.count, 2)
                XCTAssertEqual(users[0].id, 0)
                XCTAssertEqual(users[0].firstname, "John")
                XCTAssertEqual(users[1].lastname, "Mustermann")
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 0.1)
        c.cancel()
    }

    func testPostRequest() {
        StubFactory.shared.usersPost()
        
        let expectation = XCTestExpectation()

        let service = MyApi()
        let request = UserCreateRequest(user: .init(firstname: "John", lastname: "Doe"))
        let c = request.schedule(with: service).ignoreError()
            .sink { user in
                XCTAssertEqual(user.id, 2)
                XCTAssertEqual(user.firstname, "John")
                XCTAssertEqual(user.lastname, "Doe")
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 0.1)
        c.cancel()
    }
    
    func testImageRequest() {
        StubFactory.shared.usersImagePost()
        
        let expectation = XCTestExpectation()
        
        let image = UIImage(
            contentsOfFile: Bundle(for: type(of: self)).path(forResource: "cat", ofType: "jpg")!
        )!.jpegData(compressionQuality: 1)!
        
        let service = MyApi()
        let request = UserImageUploadRequest(userId: 0, image: image)
        let c = request.schedule(with: service).ignoreError()
            .sink { _ in
                expectation.fulfill()
            }
        
        wait(for: [expectation], timeout: 0.1)
        c.cancel()
    }

    func testQueryRequest() {
        StubFactory.shared.usersNameGet()
        
        let expectation = XCTestExpectation()

        let service = MyApi()
        let request = UserNameRequest(lastname: "Doe")
        let c = request.schedule(with: service).ignoreError()
            .sink { users in
                XCTAssertEqual(users.count, 1)
                XCTAssertEqual(users[0].id, 0)
                XCTAssertEqual(users[0].lastname, "Doe")
                XCTAssertEqual(users[0].firstname, "John")
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 0.1)
        c.cancel()
    }
    
    func testHttpHeaders() {
        StubFactory.shared.authorizationRequest()
        
        let expectation = XCTestExpectation()
        
        let service = MyApi()
        let request = LoginRequest()
        let c = request.schedule(with: service).ignoreError()
            .sink { _ in
                expectation.fulfill()
            }
        
        wait(for: [expectation], timeout: 0.1)
        c.cancel()
    }
    
    func testPaginationRequest() {
        StubFactory.shared.paginatingRequest()

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let expectationFinished = XCTestExpectation()

        var current = 0

        let service = MyApi()
        let request = PaginatedUsersRequest()
        let paginator = request.schedule(
            forPaginationWith: service, chunk: 1, paginatedType: PaginationContainer.self
        )

        let ticks = Just(()).delay(for: 1, scheduler: DispatchQueue.global())

        let c = paginator.connect(with: ticks).sink(receiveCompletion: { completion in
            if case .finished = completion {
                expectationFinished.fulfill()
            }
        }) { users in
            expectation.fulfill()
            XCTAssertEqual(users.count, 1)
            XCTAssertEqual(users[0].id, current)
            current += 1
        }

        wait(for: [expectation, expectationFinished], timeout: 3)
        c.cancel()
    }
    
    func testAnyStreamRequest() {
        // We run this test over the internet
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 3
        
        let request = AnyStreamRequest(url: "echo.websocket.org")
        let stream = request.schedule()
        let cancellable = stream
            .ignoreError()
            .ignoreResultErrors()
            .sink { text in
                XCTAssertEqual(text, "Echo me!")
                expectation.fulfill()
            }
        _ = stream.send("Echo me!")
        _ = stream.send("Echo me!")
        _ = stream.send("Echo me!")
        
        wait(for: [expectation], timeout: 3)
        cancellable.cancel()
    }
    
    func testMultipleSubscriptions() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true
        StubFactory.shared.usersGet(expectation: expectation)

        let service = MyApi()
        let request = UsersRequest()
        let response = request.schedule(with: service)
        
        var k: Cancellable?
        let c = response.ignoreError().sink { users in
            expectation.fulfill()
            k = response.ignoreError().sink { users in
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 0.1)
        c.cancel()
        k?.cancel()
    }
    
    func testRequestPreparation() {
        StubFactory.shared.usersGet()
        
        let expectation = XCTestExpectation()

        let service = MyApi()
        let request = ProcessingUsersRequest()
        let c = request.schedule(with: service).ignoreError()
            .sink { users in
                XCTAssertEqual(users.count, 2)
                XCTAssertEqual(users[0].id, 0)
                XCTAssertEqual(users[0].firstname, "John")
                XCTAssertEqual(users[1].lastname, "Mustermann")
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 0.1)
        c.cancel()
    }
}
