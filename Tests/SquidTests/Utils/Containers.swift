//
//  Containers.swift
//  Squid
//
//  Created by Oliver Borchert on 10/6/19.
//

import Foundation
@testable import Squid

struct UserContainer: Decodable {
    
    let id: Int
    let firstname: String
    let lastname: String
}

struct PaginationContainer<Base: Decodable>: PaginatedData, Decodable {
    
    let data: Base
    
    let page: Int
    let from: Int
    let to: Int
    let chunk: Int
    
    let totalCount: Int
    let totalPageCount: Int
}
