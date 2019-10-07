//
//  Utility.swift
//  Squid
//
//  Created by Oliver Borchert on 10/7/19.
//

import Foundation
@testable import Squid

class MyAtomicCounter {
    
    @Atomic var count = 0
    
    func increment() {
        self._count++
    }
}
