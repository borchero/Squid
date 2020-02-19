//
//  Delegates.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation

internal protocol HttpTaskSubscriptionDelegate: class {

    func receive(_ data: Data)
    func finalize(response: URLResponse?, error: Error?)
}

internal protocol WSTaskSubscriptionDelegate: class {

    func close(with error: URLSessionWebSocketTask.CloseCode, reason: Data?)
}
