//
//  Concurrency.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

// Would be nice as a property wrapper but the Swift compiler (Swift 5.1) has some bugs that cause
// weird segfaults either during compilation or at runtime.
internal class Locked<Value> {

    private var _lock = os_unfair_lock()
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        get {
            return self.locking { $0 }
        } set {
            self.locking { $0 = newValue }
        }
    }

    func locking<R>(_ block: (inout Value) throws -> R) rethrows -> R {
        self.lock()
        defer { self.unlock() }
        return try block(&self._value)
    }

    private func lock() {
        os_unfair_lock_lock(&self._lock)
    }

    private func unlock() {
        os_unfair_lock_unlock(&self._lock)
    }
}

internal class AtomicInt {

    @discardableResult
    postfix static func ++ (atomic: AtomicInt) -> Int {
        let value = atomic.value
        atomic.increment()
        return value
    }

    private let locked: Locked<Int>

    init(_ value: Int = 0) {
        self.locked = .init(value)
    }

    var value: Int {
        return locked.value
    }

    func increment() {
        self.locked.locking { $0 += 1 }
    }
}
