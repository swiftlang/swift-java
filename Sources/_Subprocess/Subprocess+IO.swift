//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

import Dispatch
import SystemPackage

// Naive Mutex so we don't have to update the macOS dependency
final class _Mutex<Value>: Sendable {
  let lock = Lock()
  
  var value: Value
  
  init(_ value: Value) {
    self.value = value
  }
  
  func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
    self.lock.lock()
    defer { self.lock.unlock() }
    return try body(&self.value)
  }
}

// MARK: - Input
extension Subprocess {
    /// `InputMethod` defines how should the standard input
    /// of the subprocess receive inputs.
    public struct InputMethod: Sendable, Hashable {
        internal enum Storage: Sendable, Hashable {
            case noInput
            case fileDescriptor(FileDescriptor, Bool)
        }

        internal let method: Storage

        internal init(method: Storage) {
            self.method = method
        }

        internal func createExecutionInput() throws -> ExecutionInput {
            switch self.method {
            case .noInput:
                let devnull: FileDescriptor = try .openDevNull(withAcessMode: .readOnly)
                return .init(storage: .noInput(devnull))
            case .fileDescriptor(let fileDescriptor, let closeWhenDone):
                return .init(storage: .fileDescriptor(fileDescriptor, closeWhenDone))
            }
        }

        /// Subprocess should read no input. This option is equivalent
        /// to bind the stanard input to `/dev/null`.
        public static var noInput: Self {
            return .init(method: .noInput)
        }

        /// Subprocess should read input from a given file descriptor.
        /// - Parameters:
        ///   - fd: the file descriptor to read from
        ///   - closeAfterSpawningProcess: whether the file descriptor
        ///     should be automatically closed after subprocess is spawned.
        public static func readFrom(
            _ fd: FileDescriptor,
            closeAfterSpawningProcess: Bool
        ) -> Self {
            return .init(method: .fileDescriptor(fd, closeAfterSpawningProcess))
        }
    }
}

extension Subprocess {
    /// `CollectedOutputMethod` defines how should Subprocess collect
    /// output from child process' standard output and standard error
    public struct CollectedOutputMethod: Sendable, Hashable {
        internal enum Storage: Sendable, Hashable {
            case discarded
            case fileDescriptor(FileDescriptor, Bool)
            case collected(Int)
        }

        internal let method: Storage

        internal init(method: Storage) {
            self.method = method
        }

        /// Subprocess shold dicard the child process output.
        /// This option is equivalent to binding the child process
        /// output to `/dev/null`.
        public static var discard: Self {
            return .init(method: .discarded)
        }
        /// Subprocess should write the child process output
        /// to the file descriptor specified.
        /// - Parameters:
        ///   - fd: the file descriptor to write to
        ///   - closeAfterSpawningProcess: whether to close the
        ///     file descriptor once the process is spawned.
        public static func writeTo(_ fd: FileDescriptor, closeAfterSpawningProcess: Bool) -> Self {
            return .init(method: .fileDescriptor(fd, closeAfterSpawningProcess))
        }
        /// Subprocess should collect the child process output
        /// as `Data` with the given limit in bytes. The default
        /// limit is 128kb.
        public static func collect(upTo limit: Int = 128 * 1024) -> Self {
            return .init(method: .collected(limit))
        }

        internal func createExecutionOutput() throws -> ExecutionOutput {
            switch self.method {
            case .discarded:
                // Bind to /dev/null
                let devnull: FileDescriptor = try .openDevNull(withAcessMode: .writeOnly)
                return .init(storage: .discarded(devnull))
            case .fileDescriptor(let fileDescriptor, let closeWhenDone):
                return .init(storage: .fileDescriptor(fileDescriptor, closeWhenDone))
            case .collected(let limit):
                let (readFd, writeFd) = try FileDescriptor.pipe()
                return .init(storage: .collected(limit, readFd, writeFd))
            }
        }
    }

    /// `CollectedOutputMethod` defines how should Subprocess redirect
    /// output from child process' standard output and standard error.
    public struct RedirectedOutputMethod: Sendable, Hashable {
        typealias Storage = CollectedOutputMethod.Storage

        internal let method: Storage

        internal init(method: Storage) {
            self.method = method
        }

        /// Subprocess shold dicard the child process output.
        /// This option is equivalent to binding the child process
        /// output to `/dev/null`.
        public static var discard: Self {
            return .init(method: .discarded)
        }
        /// Subprocess should redirect the child process output
        /// to `Subprocess.standardOutput` or `Subprocess.standardError`
        /// so they can be consumed as an AsyncSequence
        public static var redirectToSequence: Self {
            return .init(method: .collected(128 * 1024))
        }
        /// Subprocess shold write the child process output
        /// to the file descriptor specified.
        /// - Parameters:
        ///   - fd: the file descriptor to write to
        ///   - closeAfterSpawningProcess: whether to close the
        ///     file descriptor once the process is spawned.
        public static func writeTo(
            _ fd: FileDescriptor,
            closeAfterSpawningProcess: Bool
        ) -> Self {
            return .init(method: .fileDescriptor(fd, closeAfterSpawningProcess))
        }

        internal func createExecutionOutput() throws -> ExecutionOutput {
            switch self.method {
            case .discarded:
                // Bind to /dev/null
                let devnull: FileDescriptor = try .openDevNull(withAcessMode: .writeOnly)
                return .init(storage: .discarded(devnull))
            case .fileDescriptor(let fileDescriptor, let closeWhenDone):
                return .init(storage: .fileDescriptor(fileDescriptor, closeWhenDone))
            case .collected(let limit):
                let (readFd, writeFd) = try FileDescriptor.pipe()
                return .init(storage: .collected(limit, readFd, writeFd))
            }
        }
    }
}

// MARK: - Execution IO
extension Subprocess {
    internal final class ExecutionInput: Sendable, Hashable {
        

        internal enum Storage: Sendable, Hashable {
            case noInput(FileDescriptor?)
            case customWrite(FileDescriptor?, FileDescriptor?)
            case fileDescriptor(FileDescriptor?, Bool)
        }
        
        let storage: _Mutex<Storage>

        internal init(storage: Storage) {
            self.storage = .init(storage)
        }

        internal func getReadFileDescriptor() -> FileDescriptor? {
            return self.storage.withLock {
                switch $0 {
                case .noInput(let readFd):
                    return readFd
                case .customWrite(let readFd, _):
                    return readFd
                case .fileDescriptor(let readFd, _):
                    return readFd
                }
            }
        }

        internal func getWriteFileDescriptor() -> FileDescriptor? {
            return self.storage.withLock {
                switch $0 {
                case .noInput(_), .fileDescriptor(_, _):
                    return nil
                case .customWrite(_, let writeFd):
                    return writeFd
                }
            }
        }

        internal func closeChildSide() throws {
            try self.storage.withLock {
                switch $0 {
                case .noInput(let devnull):
                    try devnull?.close()
                    $0 = .noInput(nil)
                case .customWrite(let readFd, let writeFd):
                    try readFd?.close()
                    $0 = .customWrite(nil, writeFd)
                case .fileDescriptor(let fd, let closeWhenDone):
                    // User passed in fd
                    if closeWhenDone {
                        try fd?.close()
                        $0 = .fileDescriptor(nil, closeWhenDone)
                    }
                }
            }
        }

        internal func closeParentSide() throws {
            try self.storage.withLock {
                switch $0 {
                case .noInput(_), .fileDescriptor(_, _):
                    break
                case .customWrite(let readFd, let writeFd):
                    // The parent fd should have been closed
                    // in the `body` when writer.finish() is called
                    // But in case it isn't call it agian
                    try writeFd?.close()
                    $0 = .customWrite(readFd, nil)
                }
            }
        }

        internal func closeAll() throws {
            try self.storage.withLock {
                switch $0 {
                case .noInput(let readFd):
                    try readFd?.close()
                    $0 = .noInput(nil)
                case .customWrite(let readFd, let writeFd):
                    var readFdCloseError: Error?
                    var writeFdCloseError: Error?
                    do {
                        try readFd?.close()
                    } catch {
                        readFdCloseError = error
                    }
                    do {
                        try writeFd?.close()
                    } catch {
                        writeFdCloseError = error
                    }
                    $0 = .customWrite(nil, nil)
                    if let readFdCloseError {
                        throw readFdCloseError
                    }
                    if let writeFdCloseError {
                        throw writeFdCloseError
                    }
                case .fileDescriptor(let fd, let closeWhenDone):
                    if closeWhenDone {
                        try fd?.close()
                        $0 = .fileDescriptor(nil, closeWhenDone)
                    }
                }
            }
        }

        public func hash(into hasher: inout Hasher) {
            self.storage.withLock {
                hasher.combine($0)
            }
        }

        public static func == (
            lhs: Subprocess.ExecutionInput,
            rhs: Subprocess.ExecutionInput
        ) -> Bool {
            return lhs.storage.withLock { lhsStorage in
                rhs.storage.withLock { rhsStorage in
                    return lhsStorage == rhsStorage
                }
            }
        }
    }

    internal final class ExecutionOutput: Sendable {
        internal enum Storage: Sendable {
            case discarded(FileDescriptor?)
            case fileDescriptor(FileDescriptor?, Bool)
            case collected(Int, FileDescriptor?, FileDescriptor?)
        }
        
        private let storage: _Mutex<Storage>

        internal init(storage: Storage) {
            self.storage = .init(storage)
        }

        internal func getWriteFileDescriptor() -> FileDescriptor? {
            return self.storage.withLock {
                switch $0 {
                case .discarded(let writeFd):
                    return writeFd
                case .fileDescriptor(let writeFd, _):
                    return writeFd
                case .collected(_, _, let writeFd):
                    return writeFd
                }
            }
        }

        internal func getReadFileDescriptor() -> FileDescriptor? {
            return self.storage.withLock {
                switch $0 {
                case .discarded(_), .fileDescriptor(_, _):
                    return nil
                case .collected(_, let readFd, _):
                    return readFd
                }
            }
        }
        
        internal func consumeCollectedFileDescriptor() -> (limit: Int, fd: FileDescriptor?)? {
            return self.storage.withLock {
                switch $0 {
                case .discarded(_), .fileDescriptor(_, _):
                    // The output has been written somewhere else
                    return nil
                case .collected(let limit, let readFd, let writeFd):
                    $0 = .collected(limit, nil, writeFd)
                    return (limit, readFd)
                }
            }
        }

        internal func closeChildSide() throws {
            try self.storage.withLock {
                switch $0 {
                case .discarded(let writeFd):
                    try writeFd?.close()
                    $0 = .discarded(nil)
                case .fileDescriptor(let fd, let closeWhenDone):
                    // User passed fd
                    if closeWhenDone {
                        try fd?.close()
                        $0 = .fileDescriptor(nil, closeWhenDone)
                    }
                case .collected(let limit, let readFd, let writeFd):
                    try writeFd?.close()
                    $0 = .collected(limit, readFd, nil)
                }
            }
        }

        internal func closeParentSide() throws {
            try self.storage.withLock {
                switch $0 {
                case .discarded(_), .fileDescriptor(_, _):
                    break
                case .collected(let limit, let readFd, let writeFd):
                    try readFd?.close()
                    $0 = .collected(limit, nil, writeFd)
                }
            }
        }

        internal func closeAll() throws {
            try self.storage.withLock {
                switch $0 {
                case .discarded(let writeFd):
                    try writeFd?.close()
                    $0 = .discarded(nil)
                case .fileDescriptor(let fd, let closeWhenDone):
                    if closeWhenDone {
                        try fd?.close()
                        $0 = .fileDescriptor(nil, closeWhenDone)
                    }
                case .collected(let limit, let readFd, let writeFd):
                    var readFdCloseError: Error?
                    var writeFdCloseError: Error?
                    do {
                        try readFd?.close()
                    } catch {
                        readFdCloseError = error
                    }
                    do {
                        try writeFd?.close()
                    } catch {
                        writeFdCloseError = error
                    }
                    $0 = .collected(limit, nil, nil)
                    if let readFdCloseError {
                        throw readFdCloseError
                    }
                    if let writeFdCloseError {
                        throw writeFdCloseError
                    }
                }
            }
        }
    }
}

