//
//  Token.swift
//  Squid
//
//  Created by Oliver Borchert on 2/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import Foundation
import Combine

class MyStore {
    
    var token: String = "notallowed"
}

// MARK: Services

struct MyAuthApi: HttpService {
    
    private let store: MyStore
    
    init(store: MyStore) {
        self.store = store
    }
    
    var apiUrl: UrlConvertible {
        return "squid.borchero.com"
    }
    
    var token: String {
        get {
            return self.store.token
        } set {
            self.store.token = newValue
        }
    }
}

struct MyProtectedApi: HttpService {
    
    private let auth: MyAuthApi
    
    init(auth: MyAuthApi) {
        self.auth = auth
    }
    
    var apiUrl: UrlConvertible {
        return "squid.borchero.com"
    }
    
    var header: HttpHeader {
        return [.authorization: self.auth.token]
    }
    
    var retrierFactory: RetrierFactory {
        return AnyRetrierFactory {
            return TokenRetrier(auth: self.auth)
        }
    }
}

struct MyAsyncProtectedApi: HttpService {

    var apiUrl: UrlConvertible {
        return "squid.borchero.com"
    }

    var asyncHeader: Future<HttpHeader, Error> {
        return Future { promise in
            promise(.success([.authorization: "mytoken"]))
        }
    }
}

// MARK: Requests

struct TokenRequest: Request {
    
    typealias Result = String
    
    var routes: HttpRoute {
        return ["token"]
    }
}

struct ProtectedRequest: Request {
    
    typealias Result = Void
    
    var routes: HttpRoute {
        return ["protected"]
    }
}

// MARK: Retriers

class TokenRetrier: Retrier {
    
    private var auth: MyAuthApi
    private var cancellable: Cancellable?
    
    init(auth: MyAuthApi) {
        self.auth = auth
    }
    
    func retry<R>(
        _ request: R, failingWith error: Squid.Error
    ) -> Future<Bool, Never> where R: Request {
        return Future { promise in
            switch error {
            case .requestFailed(statusCode: 401, response: _):
                let request = TokenRequest()
                self.cancellable = request.schedule(with: self.auth).sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure(_):
                            // No need to repeat the request, token could not be fetched
                            promise(.success(false))
                        default:
                            break
                        }
                    }, receiveValue: { value in
                        self.auth.token = value
                        // Repeat
                        promise(.success(true))
                    })
            default:
                // No need to retry the request in this case
                promise(.success(false))
            }
        }
    }
}
