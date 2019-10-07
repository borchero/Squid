//
//  Concurrency.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

@propertyWrapper
internal class Atomic {
    
    postfix static func ++ (atomic: Atomic) -> Int64 {
        let value = atomic.value
        atomic.increment()
        return value
    }
    
    private var value: Int64
    
    init(wrappedValue: Int64) {
        self.value = wrappedValue
    }
    
    var wrappedValue: Int64 {
        return self.value
    }
    
    private func increment() {
        OSAtomicIncrement64(&self.value)
    }
}

@propertyWrapper
internal class Locked<Value> {
    
    private(set) var wrappedValue: Value
    private let lockingQueue = DispatchQueue(label: "", qos: .default)
    
    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
    
    func sync<R>(_ execute: (inout Value) -> R) -> R {
        return lockingQueue.sync {
            execute(&self.wrappedValue)
        }
    }
    
    func async(_ execute: @escaping (inout Value) -> Void) {
        lockingQueue.async {
            execute(&self.wrappedValue)
        }
    }
}
