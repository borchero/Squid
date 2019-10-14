//
//  Utility.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation
@testable import Squid

class MyAtomicCounter {
    
    var count = AtomicInt()
    
    func increment() {
        self.count.increment()
    }
}
