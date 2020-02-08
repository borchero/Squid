//
//  Stub.swift
//  Squid
//
//  Created by Oliver Borchert on 10/6/19.
//

import XCTest
import Foundation
import UIKit
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Squid

class StubFactory {
    
    internal static let shared = StubFactory()
    private let requestIsThrottled = Locked(true)
    
    private init() { }
    
    func usersGet(expectation: XCTestExpectation? = nil) {
        let descriptor = stub(
            condition: isHost("squid.borchero.com") && isMethodGET() && isPath("/users")
        ) { _ -> HTTPStubsResponse in
            expectation?.fulfill()
            let path = OHPathForFile("users.json", type(of: self))!
            return fixture(
                filePath: path,
                status: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        descriptor.name = "Users GET Stub"
    }
    
    func usersNameGet() {
        let descriptor = stub(
            condition: isHost("squid.borchero.com") && isMethodGET() && isPath("/users")
                && containsQueryParams(["lastname": "Doe"])
        ) { _ -> HTTPStubsResponse in
            let path = OHPathForFile("users.json", type(of: self))!
            let data = try! Data(contentsOf: URL(fileURLWithPath: path))
            let json = try! JSONSerialization.jsonObject(
                with: data, options: []
            ) as! [[String: Any]]
            let result = json.filter { $0["lastname"] as! String == "Doe" }

            return .init(
                data: try! JSONSerialization.data(withJSONObject: result, options: []),
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        descriptor.name = "Users Name GET Stub"
    }
    
    func usersPost() {
        let descriptor = stub(condition: { request -> Bool in
            let data = request.ohhttpStubs_httpBody!
            let json = try! JSONSerialization.jsonObject(
                with: data, options: []
            ) as! [String: String]
            
            return request.url?.host == "squid.borchero.com"
                && request.url?.path == "/users"
                && request.httpMethod == "POST"
                && Set(json.keys) == ["firstname", "lastname"]
                && json["firstname"] == "John"
                && json["lastname"] == "Doe"
        }) { request -> HTTPStubsResponse in
            let data = request.ohhttpStubs_httpBody!
            let json = try! JSONSerialization.jsonObject(
                with: data, options: []
            ) as! [String: String]
            
            let responseJson = [
                "firstname": json["firstname"]!,
                "lastname": json["lastname"]!,
                "id": 2
            ] as [String : Any]
            let responseData = try! JSONSerialization.data(
                withJSONObject: responseJson, options: []
            )
            
            return .init(
                data: responseData,
                statusCode: 201,
                headers: ["Content-Type": "application/json"]
            )
        }
        descriptor.name = "Users POST Stub"
    }
    
    func usersImagePost() {
        let descriptor = stub(condition: { request -> Bool in
            let data = request.ohhttpStubs_httpBody!
            let originalImage = UIImage(
                contentsOfFile: Bundle(for: type(of: self)).path(forResource: "cat", ofType: "jpg")!
            )!
            let originalData = originalImage.jpegData(compressionQuality: 1)!
            
            return request.url?.host == "squid.borchero.com"
                && request.url?.path == "/users/0/image"
                && request.httpMethod == "POST"
                && request.allHTTPHeaderFields?["Content-Type"] == "image/jpeg"
                && request.allHTTPHeaderFields?["Content-Length"] == "30904"
                && data.count == 30904
                && data == originalData
        }) { _ -> HTTPStubsResponse in
            return .init(data: Data(), statusCode: 201, headers: [:])
        }
        descriptor.name = "Users Image POST Stub"
    }
    
    func authorizationRequest() {
        let descriptor = stub(
            condition: isHost("squid.borchero.com") && isMethodPOST() && isPath("/login")
                && hasHeaderNamed("Authorization", value: "letmepass")
                && hasHeaderNamed("Content-Type", value: "application/json")
                && hasHeaderNamed("Accept-Language", value: "en")
        ) { _ -> HTTPStubsResponse in
            return .init(data: Data(), statusCode: 200, headers: [:])
        }
        descriptor.name = "Authorization Stub"
    }
    
    func unauthorizedRequest() {
        let descriptor = stub(
            condition: isHost("squid.borchero.com") && isMethodGET() && isPath("/authorize")
        ) { _ -> HTTPStubsResponse in
            return .init(data: Data(), statusCode: 401, headers: [:])
        }
        descriptor.name = "401 Stub"
    }
    
    func paginatingRequest() {
        var counter = 0
        let descriptor = stub(condition: { request -> Bool in
            let expectedIndex = counter + 1
            return request.url?.host == "squid.borchero.com"
                && request.url?.path == "/pagination"
                && request.httpMethod == "GET"
                && (request.url?.query == "page=\(expectedIndex)&chunk=1"
                    || request.url?.query == "chunk=1&page=\(expectedIndex)")
        }) { request -> HTTPStubsResponse in
            let path = OHPathForFile("users.json", type(of: self))!
            let data = try! Data(contentsOf: URL(fileURLWithPath: path))
            let json = try! JSONSerialization.jsonObject(
                with: data, options: []
            ) as! [[String: Any]]

            let response = json.filter { ($0["id"] as! Int) == counter }
            let finalResponse: [String: Any] = [
                "data": response,
                "page": counter + 1,
                "from": counter + 1,
                "to": counter + 2,
                "chunk": 1,
                "totalCount": 2,
                "totalPageCount": 2
            ]
            let responseData = try! JSONSerialization.data(
                withJSONObject: finalResponse, options: []
            )
            counter += 1

            return .init(
                data: responseData,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
        descriptor.name = "Pagination Stub"
    }
}
