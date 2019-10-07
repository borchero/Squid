//
//  Stream.swift
//  Squid
//
//  Created by Oliver Borchert on 10/5/19.
//

import Foundation

public protocol Stream {
    
    associatedtype Message = Void
    associatedtype Result
    
    var routingPaths: [String] { get }
    var query: HttpQuery { get }
    
    var priority: RequestPriority { get }
    
    func decode(_ message: URLSessionWebSocketTask.Message) throws -> Result
}
