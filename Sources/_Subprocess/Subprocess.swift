//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import SystemPackage

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// An object that represents a subprocess of the current process.
///
/// Using `Subprocess`, your program can run another program as a subprocess
/// and can monitor that program’s execution. A `Subprocess` object creates a
/// **separate executable** entity; it’s different from `Thread` because it doesn’t
/// share memory space with the process that creates it.
public struct Subprocess: Sendable {
    /// The process identifier of the current subprocess
    public let processIdentifier: ProcessIdentifier

    internal let executionInput: ExecutionInput
    internal let executionOutput: ExecutionOutput
    internal let executionError: ExecutionOutput
#if os(Windows)
    internal let consoleBehavior: PlatformOptions.ConsoleBehavior
#endif

    /// The standard output of the subprocess.
    /// Accessing this property will **fatalError** if
    /// - `.output` wasn't set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed ones.
    public var standardOutput: some _AsyncSequence<Data, any Error> {
        guard let (_, fd) = self.executionOutput
            .consumeCollectedFileDescriptor() else {
            fatalError("The standard output was not redirected")
        }
        guard let fd = fd else {
            fatalError("The standard output has already been closed")
        }
        return AsyncDataSequence(fileDescriptor: fd)
    }

    /// The standard error of the subprocess.
    /// Accessing this property will **fatalError** if
    /// - `.error` wasn't set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed ones.
    public var standardError: some _AsyncSequence<Data, any Error> {
        guard let (_, fd) = self.executionError
            .consumeCollectedFileDescriptor() else {
            fatalError("The standard error was not redirected")
        }
        guard let fd = fd else {
            fatalError("The standard error has already been closed")
        }
        return AsyncDataSequence(fileDescriptor: fd)
    }
}

// MARK: - Teardown
#if canImport(Darwin) || canImport(Glibc)
extension Subprocess {
    /// Performs a sequence of teardown steps on the Subprocess.
    /// Teardown sequence always ends with a `.kill` signal
    /// - Parameter sequence: The  steps to perform.
    public func teardown(using sequence: [TeardownStep]) async {
        await withUncancelledTask {
            await self.runTeardownSequence(sequence)
        }
    }
}
#endif

// MARK: - StandardInputWriter
extension Subprocess {
    /// A writer that writes to the standard input of the subprocess.
    public struct StandardInputWriter {

        private let input: ExecutionInput

        init(input: ExecutionInput) {
            self.input = input
        }

        /// Write a sequence of UInt8 to the standard input of the subprocess.
        /// - Parameter sequence: The sequence of bytes to write.
        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == UInt8 {
            guard let fd: FileDescriptor = self.input.getWriteFileDescriptor() else {
                fatalError("Attempting to write to a file descriptor that's already closed")
            }
            try await fd.write(sequence)
        }

        /// Write a sequence of CChar to the standard input of the subprocess.
        /// - Parameter sequence: The sequence of bytes to write.
        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == CChar {
            try await self.write(sequence.map { UInt8($0) })
        }

        /// Write a AsyncSequence of CChar to the standard input of the subprocess.
        /// - Parameter sequence: The sequence of bytes to write.
        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == CChar {
            let sequence = try await Array(asyncSequence).map { UInt8($0) }
            try await self.write(sequence)
        }

        /// Write a AsyncSequence of UInt8 to the standard input of the subprocess.
        /// - Parameter sequence: The sequence of bytes to write.
        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == UInt8 {
            let sequence = try await Array(asyncSequence)
            try await self.write(sequence)
        }

        /// Signal all writes are finished
        public func finish() async throws {
            try self.input.closeParentSide()
        }
    }
}

@available(macOS, unavailable)
@available(iOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(*, unavailable)
extension Subprocess.StandardInputWriter : Sendable {}

// MARK: - Result
extension Subprocess {
    /// A simple wrapper around the generic result returned by the
    /// `run` closures with the corresponding `TerminationStatus`
    /// of the child process.
    public struct ExecutionResult<T: Sendable>: Sendable {
        /// The termination status of the child process
        public let terminationStatus: TerminationStatus
        /// The result returned by the closure passed to `.run` methods
        public let value: T

        internal init(terminationStatus: TerminationStatus, value: T) {
            self.terminationStatus = terminationStatus
            self.value = value
        }
    }

    /// The result of a subprocess execution with its collected
    /// standard output and standard error.
    public struct CollectedResult: Sendable, Hashable, Codable {
        /// The process identifier for the executed subprocess
        public let processIdentifier: ProcessIdentifier
        /// The termination status of the executed subprocess
        public let terminationStatus: TerminationStatus
        private let _standardOutput: Data?
        private let _standardError: Data?

        /// The collected standard output value for the subprocess.
        /// Accessing this property will *fatalError* if the
        /// corresponding `CollectedOutputMethod` is not set to
        /// `.collect` or `.collect(upTo:)`
        public var standardOutput: Data {
            guard let output = self._standardOutput else {
                fatalError("standardOutput is only available if the Subprocess was ran with .collect as output")
            }
            return output
        }
        /// The collected standard error value for the subprocess.
        /// Accessing this property will *fatalError* if the
        /// corresponding `CollectedOutputMethod` is not set to
        /// `.collect` or `.collect(upTo:)`
        public var standardError: Data {
            guard let output = self._standardError else {
                fatalError("standardError is only available if the Subprocess was ran with .collect as error ")
            }
            return output
        }

        internal init(
            processIdentifier: ProcessIdentifier,
            terminationStatus: TerminationStatus,
            standardOutput: Data?,
            standardError: Data?) {
            self.processIdentifier = processIdentifier
            self.terminationStatus = terminationStatus
            self._standardOutput = standardOutput
            self._standardError = standardError
        }
    }
}

extension Subprocess.ExecutionResult: Equatable where T : Equatable {}

extension Subprocess.ExecutionResult: Hashable where T : Hashable {}

extension Subprocess.ExecutionResult: Codable where T : Codable {}

extension Subprocess.ExecutionResult: CustomStringConvertible where T : CustomStringConvertible {
    public var description: String {
        return """
Subprocess.ExecutionResult(
    terminationStatus: \(self.terminationStatus.description),
    value: \(self.value.description)
)
"""
    }
}

extension Subprocess.ExecutionResult: CustomDebugStringConvertible where T : CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
Subprocess.ExecutionResult(
    terminationStatus: \(self.terminationStatus.debugDescription),
    value: \(self.value.debugDescription)
)
"""
    }
}

extension Subprocess.CollectedResult : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return """
Subprocess.CollectedResult(
    processIdentifier: \(self.processIdentifier.description),
    terminationStatus: \(self.terminationStatus.description),
    standardOutput: \(self._standardOutput?.description ?? "not captured"),
    standardError: \(self._standardError?.description ?? "not captured")
)
"""
    }

    public var debugDescription: String {
        return """
Subprocess.CollectedResult(
    processIdentifier: \(self.processIdentifier.debugDescription),
    terminationStatus: \(self.terminationStatus.debugDescription),
    standardOutput: \(self._standardOutput?.debugDescription ?? "not captured"),
    standardError: \(self._standardError?.debugDescription ?? "not captured")
)
"""
    }
}

// MARK: - Internal
extension Subprocess {
    internal enum OutputCapturingState {
        case standardOutputCaptured(Data?)
        case standardErrorCaptured(Data?)
    }

    internal typealias CapturedIOs = (standardOutput: Data?, standardError: Data?)

    private func capture(fileDescriptor: FileDescriptor, maxLength: Int) async throws -> Data {
        return try await fileDescriptor.readUntilEOF(upToLength: maxLength)
    }

    internal func captureStandardOutput() async throws -> Data? {
        guard let (limit, readFd) = self.executionOutput
            .consumeCollectedFileDescriptor(),
              let readFd = readFd else {
            return nil
        }
        defer {
            try? readFd.close()
        }
        return try await self.capture(fileDescriptor: readFd, maxLength: limit)
    }

    internal func captureStandardError() async throws -> Data? {
        guard let (limit, readFd) = self.executionError
            .consumeCollectedFileDescriptor(),
              let readFd = readFd else {
            return nil
        }
        defer {
            try? readFd.close()
        }
        return try await self.capture(fileDescriptor: readFd, maxLength: limit)
    }

    internal func captureIOs() async throws -> CapturedIOs {
        return try await withThrowingTaskGroup(of: OutputCapturingState.self) { group in
            group.addTask {
                let stdout = try await self.captureStandardOutput()
                return .standardOutputCaptured(stdout)
            }
            group.addTask {
                let stderr = try await self.captureStandardError()
                return .standardErrorCaptured(stderr)
            }
            
            var stdout: Data?
            var stderror: Data?
            while let state = try await group.next() {
                switch state {
                case .standardOutputCaptured(let output):
                    stdout = output
                case .standardErrorCaptured(let error):
                    stderror = error
                }
            }
            return (standardOutput: stdout, standardError: stderror)
        }
    }
}
