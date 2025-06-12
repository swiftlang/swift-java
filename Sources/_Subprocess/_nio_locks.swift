//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import ucrt
import WinSDK
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
#error("The concurrency lock module was unable to identify your C library.")
#endif

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO. On Windows, the lock is based on the substantially similar
/// `SRWLOCK` type.
@available(*, deprecated, renamed: "NIOLock")
public final class Lock {
#if os(Windows)
    fileprivate let mutex: UnsafeMutablePointer<SRWLOCK> =
        UnsafeMutablePointer.allocate(capacity: 1)
#else
    fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
#endif

    /// Create a new lock.
    public init() {
#if os(Windows)
        InitializeSRWLock(self.mutex)
#else
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        debugOnly {
            pthread_mutexattr_settype(&attr, .init(PTHREAD_MUTEX_ERRORCHECK))
        }

        let err = pthread_mutex_init(self.mutex, &attr)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }

    deinit {
#if os(Windows)
        // SRWLOCK does not need to be free'd
#else
        let err = pthread_mutex_destroy(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
        mutex.deallocate()
    }

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lock() {
#if os(Windows)
        AcquireSRWLockExclusive(self.mutex)
#else
        let err = pthread_mutex_lock(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    public func unlock() {
#if os(Windows)
        ReleaseSRWLockExclusive(self.mutex)
#else
        let err = pthread_mutex_unlock(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }

    /// Acquire the lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    public func withLockVoid(_ body: () throws -> Void) rethrows -> Void {
        try self.withLock(body)
    }
}

/// A `Lock` with a built-in state variable.
///
/// This class provides a convenience addition to `Lock`: it provides the ability to wait
/// until the state variable is set to a specific value to acquire the lock.
public final class ConditionLock<T: Equatable> {
    private var _value: T
    private let mutex: NIOLock
#if os(Windows)
    private let cond: UnsafeMutablePointer<CONDITION_VARIABLE> =
        UnsafeMutablePointer.allocate(capacity: 1)
#else
    private let cond: UnsafeMutablePointer<pthread_cond_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
#endif

    /// Create the lock, and initialize the state variable to `value`.
    ///
    /// - Parameter value: The initial value to give the state variable.
    public init(value: T) {
        self._value = value
        self.mutex = NIOLock()
#if os(Windows)
        InitializeConditionVariable(self.cond)
#else
        let err = pthread_cond_init(self.cond, nil)
        precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
#endif
    }

    deinit {
#if os(Windows)
        // condition variables do not need to be explicitly destroyed
#else
        let err = pthread_cond_destroy(self.cond)
        precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
#endif
        self.cond.deallocate()
    }

    /// Acquire the lock, regardless of the value of the state variable.
    public func lock() {
        self.mutex.lock()
    }

    /// Release the lock, regardless of the value of the state variable.
    public func unlock() {
        self.mutex.unlock()
    }

    /// The value of the state variable.
    ///
    /// Obtaining the value of the state variable requires acquiring the lock.
    /// This means that it is not safe to access this property while holding the
    /// lock: it is only safe to use it when not holding it.
    public var value: T {
        self.lock()
        defer {
            self.unlock()
        }
        return self._value
    }

    /// Acquire the lock when the state variable is equal to `wantedValue`.
    ///
    /// - Parameter wantedValue: The value to wait for the state variable
    ///     to have before acquiring the lock.
    public func lock(whenValue wantedValue: T) {
        self.lock()
        while true {
            if self._value == wantedValue {
                break
            }
            self.mutex.withLockPrimitive { mutex in
#if os(Windows)
                let result = SleepConditionVariableSRW(self.cond, mutex, INFINITE, 0)
                precondition(result, "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())")
#else
                let err = pthread_cond_wait(self.cond, mutex)
                precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
#endif
            }
        }
    }

    /// Acquire the lock when the state variable is equal to `wantedValue`,
    /// waiting no more than `timeoutSeconds` seconds.
    ///
    /// - Parameter wantedValue: The value to wait for the state variable
    ///     to have before acquiring the lock.
    /// - Parameter timeoutSeconds: The number of seconds to wait to acquire
    ///     the lock before giving up.
    /// - Returns: `true` if the lock was acquired, `false` if the wait timed out.
    public func lock(whenValue wantedValue: T, timeoutSeconds: Double) -> Bool {
        precondition(timeoutSeconds >= 0)

#if os(Windows)
        var dwMilliseconds: DWORD = DWORD(timeoutSeconds * 1000)

        self.lock()
        while true {
            if self._value == wantedValue {
                return true
            }

            let dwWaitStart = timeGetTime()
            if !SleepConditionVariableSRW(self.cond, self.mutex._storage.mutex,
                                          dwMilliseconds, 0) {
                let dwError = GetLastError()
                if (dwError == ERROR_TIMEOUT) {
                    self.unlock()
                    return false
                }
                fatalError("SleepConditionVariableSRW: \(dwError)")
            }

            // NOTE: this may be a spurious wakeup, adjust the timeout accordingly
            dwMilliseconds = dwMilliseconds - (timeGetTime() - dwWaitStart)
        }
#else
        let nsecPerSec: Int64 = 1000000000
        self.lock()
        /* the timeout as a (seconds, nano seconds) pair */
        let timeoutNS = Int64(timeoutSeconds * Double(nsecPerSec))

        var curTime = timeval()
        gettimeofday(&curTime, nil)

        let allNSecs: Int64 = timeoutNS + Int64(curTime.tv_usec) * 1000
        var timeoutAbs = timespec(tv_sec: curTime.tv_sec + Int((allNSecs / nsecPerSec)),
                                  tv_nsec: Int(allNSecs % nsecPerSec))
        assert(timeoutAbs.tv_nsec >= 0 && timeoutAbs.tv_nsec < Int(nsecPerSec))
        assert(timeoutAbs.tv_sec >= curTime.tv_sec)
        return self.mutex.withLockPrimitive { mutex -> Bool in
            while true {
                if self._value == wantedValue {
                    return true
                }
                switch pthread_cond_timedwait(self.cond, mutex, &timeoutAbs) {
                case 0:
                    continue
                case ETIMEDOUT:
                    self.unlock()
                    return false
                case let e:
                    fatalError("caught error \(e) when calling pthread_cond_timedwait")
                }
            }
        }
#endif
    }

    /// Release the lock, setting the state variable to `newValue`.
    ///
    /// - Parameter newValue: The value to give to the state variable when we
    ///     release the lock.
    public func unlock(withValue newValue: T) {
        self._value = newValue
        self.unlock()
#if os(Windows)
        WakeAllConditionVariable(self.cond)
#else
        let err = pthread_cond_broadcast(self.cond)
        precondition(err == 0, "\(#function) failed in pthread_cond with error \(err)")
#endif
    }
}

/// A utility function that runs the body code only in debug builds, without
/// emitting compiler warnings.
///
/// This is currently the only way to do this in Swift: see
/// https://forums.swift.org/t/support-debug-only-code/11037 for a discussion.
@inlinable
internal func debugOnly(_ body: () -> Void) {
    assert({ body(); return true }())
}

@available(*, deprecated)
extension Lock: @unchecked Sendable {}
extension ConditionLock: @unchecked Sendable {}

#if os(Windows)
@usableFromInline
typealias LockPrimitive = SRWLOCK
#else
@usableFromInline
typealias LockPrimitive = pthread_mutex_t
#endif

@usableFromInline
enum LockOperations { }

extension LockOperations {
    @inlinable
    static func create(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
        mutex.assertValidAlignment()

#if os(Windows)
        InitializeSRWLock(mutex)
#else
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        debugOnly {
            pthread_mutexattr_settype(&attr, .init(PTHREAD_MUTEX_ERRORCHECK))
        }
        
        let err = pthread_mutex_init(mutex, &attr)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
    
    @inlinable
    static func destroy(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
        mutex.assertValidAlignment()

#if os(Windows)
        // SRWLOCK does not need to be free'd
#else
        let err = pthread_mutex_destroy(mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
    
    @inlinable
    static func lock(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
        mutex.assertValidAlignment()

#if os(Windows)
        AcquireSRWLockExclusive(mutex)
#else
        let err = pthread_mutex_lock(mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
    
    @inlinable
    static func unlock(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
        mutex.assertValidAlignment()

#if os(Windows)
        ReleaseSRWLockExclusive(mutex)
#else
        let err = pthread_mutex_unlock(mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
}

// Tail allocate both the mutex and a generic value using ManagedBuffer.
// Both the header pointer and the elements pointer are stable for
// the class's entire lifetime.
//
// However, for safety reasons, we elect to place the lock in the "elements"
// section of the buffer instead of the head. The reasoning here is subtle,
// so buckle in.
//
// _As a practical matter_, the implementation of ManagedBuffer ensures that
// the pointer to the header is stable across the lifetime of the class, and so
// each time you call `withUnsafeMutablePointers` or `withUnsafeMutablePointerToHeader`
// the value of the header pointer will be the same. This is because ManagedBuffer uses
// `Builtin.addressOf` to load the value of the header, and that does ~magic~ to ensure
// that it does not invoke any weird Swift accessors that might copy the value.
//
// _However_, the header is also available via the `.header` field on the ManagedBuffer.
// This presents a problem! The reason there's an issue is that `Builtin.addressOf` and friends
// do not interact with Swift's exclusivity model. That is, the various `with` functions do not
// conceptually trigger a mutating access to `.header`. For elements this isn't a concern because
// there's literally no other way to perform the access, but for `.header` it's entirely possible
// to accidentally recursively read it.
//
// Our implementation is free from these issues, so we don't _really_ need to worry about it.
// However, out of an abundance of caution, we store the Value in the header, and the LockPrimitive
// in the trailing elements. We still don't use `.header`, but it's better to be safe than sorry,
// and future maintainers will be happier that we were cautious.
//
// See also: https://github.com/apple/swift/pull/40000
@usableFromInline
final class LockStorage<Value>: ManagedBuffer<Value, LockPrimitive> {
    
    @inlinable
    static func create(value: Value) -> Self {
        let buffer = Self.create(minimumCapacity: 1) { _ in
            return value
        }
        let storage = unsafeDowncast(buffer, to: Self.self)
        
        storage.withUnsafeMutablePointers { _, lockPtr in
            LockOperations.create(lockPtr)
        }
        
        return storage
    }
    
    @inlinable
    func lock() {
        self.withUnsafeMutablePointerToElements { lockPtr in
            LockOperations.lock(lockPtr)
        }
    }
    
    @inlinable
    func unlock() {
        self.withUnsafeMutablePointerToElements { lockPtr in
            LockOperations.unlock(lockPtr)
        }
    }
    
    @inlinable
    deinit {
        self.withUnsafeMutablePointerToElements { lockPtr in
            LockOperations.destroy(lockPtr)
        }
    }
    
    @inlinable
    func withLockPrimitive<T>(_ body: (UnsafeMutablePointer<LockPrimitive>) throws -> T) rethrows -> T {
        try self.withUnsafeMutablePointerToElements { lockPtr in
            return try body(lockPtr)
        }
    }
    
    @inlinable
    func withLockedValue<T>(_ mutate: (inout Value) throws -> T) rethrows -> T {
        try self.withUnsafeMutablePointers { valuePtr, lockPtr in
            LockOperations.lock(lockPtr)
            defer { LockOperations.unlock(lockPtr) }
            return try mutate(&valuePtr.pointee)
        }
    }
}

extension LockStorage: @unchecked Sendable { }

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// - note: ``NIOLock`` has reference semantics.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO. On Windows, the lock is based on the substantially similar
/// `SRWLOCK` type.
public struct NIOLock {
    @usableFromInline
    internal let _storage: LockStorage<Void>
    
    /// Create a new lock.
    @inlinable
    public init() {
        self._storage = .create(value: ())
    }

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    @inlinable
    public func lock() {
        self._storage.lock()
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    @inlinable
    public func unlock() {
        self._storage.unlock()
    }

    @inlinable
    internal func withLockPrimitive<T>(_ body: (UnsafeMutablePointer<LockPrimitive>) throws -> T) rethrows -> T {
        return try self._storage.withLockPrimitive(body)
    }
}

extension NIOLock {
    /// Acquire the lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try body()
    }

    @inlinable
    public func withLockVoid(_ body: () throws -> Void) rethrows -> Void {
        try self.withLock(body)
    }
}

extension NIOLock: Sendable {}

extension UnsafeMutablePointer {
    @inlinable
    func assertValidAlignment() {
        assert(UInt(bitPattern: self) % UInt(MemoryLayout<Pointee>.alignment) == 0)
    }
}
