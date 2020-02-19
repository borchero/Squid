//
//  Dictionary.swift
//  Squid
//
//  Created by Oliver Borchert on 9/23/19.
//

import Foundation

extension Dictionary where Key == String, Value == String {

    internal var httpHeaderDescription: String? {
        if self.isEmpty {
            return nil
        }
        return self
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { item in
                return "* \(item.key) => \(item.value)"
            }.joined(separator: "\n")
    }
}
