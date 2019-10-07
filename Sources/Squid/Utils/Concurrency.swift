//
//  Concurrency.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

@propertyWrapper
internal class Atomic<Value: Numeric> {
    
    @discardableResult
    postfix static func ++ (atomic: Atomic) -> Value {
        let value = atomic.value
        atomic.increment()
        return value
    }
    
    private var value: Value
    private let lockingQueue = DispatchQueue(label: "")
    
    init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    var wrappedValue: Value {
        return self.lockingQueue.sync { self.value }
    }
    
    private func increment() {
        self.lockingQueue.sync {
            self.value += 1
        }
    }
}

@propertyWrapper
internal class RWLocked<Value> {
    
    private let lock = DispatchQueue(label: "", attributes: .concurrent)
    private var value: Value
    
    init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    var wrappedValue: Value {
        get {
            return self.read { $0 }
        } set {
            self.write { $0 = newValue }
        }
    }
    
    func set(_ value: Value) {
        self.value = value
    }
    
    func read<R>(_ execute: (Value) throws -> R) rethrows -> R {
        return try lock.sync {
            try execute(self.value)
        }
    }
    
    func write<R>(_ execute: (inout Value) throws -> R) rethrows -> R {
        return try lock.sync(flags: .barrier) {
            return try execute(&self.value)
        }
    }
}
