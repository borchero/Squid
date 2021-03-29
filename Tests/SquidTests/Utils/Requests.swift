//
//  Requests.swift
//  SquidTests
//
//  Created by Oliver Borchert on 10/6/19.
//

import Foundation
@testable import Squid

struct UsersRequest: JsonRequest {
    
    typealias Result = [UserContainer]
    
    var routes: HttpRoute {
        return ["users"]
    }
}

struct NotCachableUsersRequest: JsonRequest {
    
    typealias Result = [UserContainer]
    
    var routes: HttpRoute {
        return ["users"]
    }
    
    var shouldCacheResult: Bool {
        return false
    }
}

struct AuthorizeRequest: Request {
    
    typealias Result = Void
    
    var routes: HttpRoute {
        return ["authorize"]
    }
}

struct UserCreateRequest: JsonRequest {
    
    typealias Result = UserContainer
    
    let user: UserBag
    
    var method: HttpMethod {
        return .post
    }
    
    var routes: HttpRoute {
        return ["users"]
    }
    
    var body: HttpBody {
        return HttpData.Json(user)
    }
    
    var acceptedStatusCodes: CountableClosedRange<Int> {
        return 201...201
    }
}

struct UserNameRequest: JsonRequest {
    
    typealias Result = [UserContainer]
    
    let lastname: String
    
    var routes: HttpRoute {
        return ["users"]
    }
    
    var query: HttpQuery {
        return ["lastname": lastname]
    }
}

struct UserImageUploadRequest: Request {
    
    typealias Result = Void
    
    let userId: Int
    let image: Data
    
    var method: HttpMethod {
        return .post
    }
    
    var routes: HttpRoute {
        return ["users", userId, "image"]
    }
    
    var body: HttpBody {
        return HttpData.Image(.jpeg, data: image)
    }
}

struct ThrottledRequest: Request {
    
    typealias Result = Void
    
    var routes: HttpRoute {
        return ["throttle"]
    }
}

struct LoginRequest: Request {
    
    typealias Result = Void
    
    var method: HttpMethod {
        return .post
    }
    
    var routes: HttpRoute {
        return ["login"]
    }
    
    var header: HttpHeader {
        // This looks ugly, but we want to test the "+" operator
        return [.authorization: "wrong"] + [.acceptLanguage: "en"] + [.authorization: "letmepass"]
    }
    
    var body: HttpBody {
        return HttpData.Json(["username": "johndoe", "password": "123456"])
    }
}

struct PaginatedUsersRequest: JsonRequest {
    
    typealias Result = [UserContainer]
    
    var routes: HttpRoute {
        return ["pagination"]
    }
}

struct ProcessingUsersRequest: JsonRequest {
    
    typealias Result = [UserContainer]
    
    func prepare(_ request: URLRequest) -> URLRequest {
        var request = request
        request.url = request.url?.appendingPathComponent("users")
        return request
    }
}
