//
//  UtilsTests.swift
//  Squid
//
//  Created by Oliver Borchert on 2/8/20.
//  Copyright © 2020 Oliver Borchert. All rights reserved.
//

import XCTest
@testable import Squid

final class UtilsTests: XCTestCase {
    
    func testAtomicCounter() {
        let counter = MyAtomicCounter()
        
        threadPool(10) {
            for _ in 0..<1_000 {
                counter.increment()
            }
        }
        
        XCTAssertEqual(counter.count.value, 10_000)
    }
    
    private func threadPool(_ count: Int = 8, execute: @escaping () -> Void) {
        var threads: [Thread] = []
        
        // Create threads
        for _ in 0..<count {
            let thread = Thread(block: execute)
            threads.append(thread)
            thread.start()
        }
        
        // "Join" threads (busy waiting)
        for thread in threads {
            while !thread.isFinished { }
        }
    }
}
