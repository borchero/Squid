//
//  Stream.swift
//  Squid
//
//  Created by Oliver Borchert on 10/5/19.
//

import Foundation

public protocol StreamRequest {
    
    associatedtype Message = Void
    associatedtype Result
    
    var routes: HttpRoute { get }
    var query: HttpQuery { get }
    
    var priority: RequestPriority { get }
    
    func decode(_ message: URLSessionWebSocketTask.Message) throws -> Result
}
