//
//  TaskSubscription.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation

internal protocol TaskSubscription {
    
    func receive(_ data: Data)
    func finalize(response: URLResponse?, error: Error?)
}
