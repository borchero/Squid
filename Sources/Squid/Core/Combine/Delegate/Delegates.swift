//
//  Delegates.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation

internal protocol HttpTaskSubscriptionDelegate: AnyObject {

    func receive(_ data: Data)
    func finalize(response: URLResponse?, error: Error?)
}

internal protocol WSTaskSubscriptionDelegate: AnyObject {

    func close(with error: URLSessionWebSocketTask.CloseCode, reason: Data?)
}
