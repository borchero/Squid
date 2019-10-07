//
//  SquidTests.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import XCTest
import OHHTTPStubsCore
import OHHTTPStubsSwift
@testable import Squid

final class SquidTests: XCTestCase {
    
    static var allTests = [
        ("testAnyRequest", testAnyRequest),
        ("testRequest", testRequest),
        ("testPostRequest", testPostRequest),
        ("testImageRequest", testImageRequest),
        ("testQueryRequest", testQueryRequest),
        ("testBackoffRetrier", testBackoffRetrier),
        ("testHttpHeaders", testHttpHeaders)
    ]
    
    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
    }
    
    func testAnyRequest() {
        StubFactory.shared.usersGet()
        
        Squid.Logger.silence(true)
        let expectation = XCTestExpectation()
        
        let request = AnyRequest(url: "https://squid.borchero.com/users")
        let task = request.schedule()
            .decode(type: [UserContainer].self, decoder: JSONDecoder())
            .sink(receiveCompletion: { _ in }, receiveValue: { users in
                XCTAssertEqual(users.count, 2)
                XCTAssertEqual(users[0].id, 0)
                XCTAssertEqual(users[0].firstname, "John")
                XCTAssertEqual(users[1].lastname, "Mustermann")
                expectation.fulfill()
            })
        
        wait(for: [expectation], timeout: 0.1)
        task.cancel()
        Squid.Logger.silence(false)
    }
    
    func testRequest() {
        StubFactory.shared.usersGet()
        
        let expectation = XCTestExpectation()

        let service = MyApi()
        let request = UsersRequest()
        request.schedule(with: service)
            .expect { users in
                XCTAssertEqual(users.count, 2)
                XCTAssertEqual(users[0].id, 0)
                XCTAssertEqual(users[0].firstname, "John")
                XCTAssertEqual(users[1].lastname, "Mustermann")
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 0.1)
    }

    func testPostRequest() {
        StubFactory.shared.usersPost()
        
        let expectation = XCTestExpectation()

        let service = MyApi()
        let request = UserCreateRequest(user: .init(firstname: "John", lastname: "Doe"))
        request.schedule(with: service)
            .expect { user in
                XCTAssertEqual(user.id, 2)
                XCTAssertEqual(user.firstname, "John")
                XCTAssertEqual(user.lastname, "Doe")
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 0.1)
    }
    
    func testImageRequest() {
        StubFactory.shared.usersImagePost()
        
        let expectation = XCTestExpectation()
        
        let image = UIImage(
            contentsOfFile: Bundle(for: type(of: self)).path(forResource: "cat", ofType: "jpg")!
        )!.jpegData(compressionQuality: 1)!
        
        let service = MyApi()
        let request = UserImageUploadRequest(userId: 0, image: image)
        request.schedule(with: service)
            .expect { _ in
                expectation.fulfill()
            }
        
        wait(for: [expectation], timeout: 0.1)
    }

    func testQueryRequest() {
        StubFactory.shared.usersNameGet()
        
        let expectation = XCTestExpectation()

        let service = MyApi()
        let request = UserNameRequest(lastname: "Doe")
        request.schedule(with: service)
            .expect { users in
                XCTAssertEqual(users.count, 1)
                XCTAssertEqual(users[0].id, 0)
                XCTAssertEqual(users[0].lastname, "Doe")
                XCTAssertEqual(users[0].firstname, "John")
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 0.1)
    }

    func testBackoffRetrier() {
        StubFactory.shared.enableThrottling(true)
        StubFactory.shared.throttlingRequest()
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            StubFactory.shared.enableThrottling(false)
        }
        
        let expectation = XCTestExpectation()

        let service = MyRetryingApi()
        let request = ThrottledRequest()
        request.schedule(with: service)
            .expect { _ in
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: 32)
    }
    
    func testHttpHeaders() {
        StubFactory.shared.authorizationRequest()
        
        let expectation = XCTestExpectation()
        
        let service = MyApi()
        let request = LoginRequest()
        request.schedule(with: service)
            .expect { _ in
                expectation.fulfill()
            }
        
        wait(for: [expectation], timeout: 0.1)
    }
}
