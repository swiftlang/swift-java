//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

// MARK: - Result

/// A simple wrapper around the generic result returned by the
/// `run` closures with the corresponding `TerminationStatus`
/// of the child process.
public struct ExecutionResult<Result> {
    /// The termination status of the child process
    public let terminationStatus: TerminationStatus
    /// The result returned by the closure passed to `.run` methods
    public let value: Result

    internal init(terminationStatus: TerminationStatus, value: Result) {
        self.terminationStatus = terminationStatus
        self.value = value
    }
}

/// The result of a subprocess execution with its collected
/// standard output and standard error.
public struct CollectedResult<
    Output: OutputProtocol,
    Error: OutputProtocol
>: Sendable {
    /// The process identifier for the executed subprocess
    public let processIdentifier: ProcessIdentifier
    /// The termination status of the executed subprocess
    public let terminationStatus: TerminationStatus
    public let standardOutput: Output.OutputType
    public let standardError: Error.OutputType

    internal init(
        processIdentifier: ProcessIdentifier,
        terminationStatus: TerminationStatus,
        standardOutput: Output.OutputType,
        standardError: Error.OutputType
    ) {
        self.processIdentifier = processIdentifier
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

// MARK: - CollectedResult Conformances
extension CollectedResult: Equatable where Output.OutputType: Equatable, Error.OutputType: Equatable {}

extension CollectedResult: Hashable where Output.OutputType: Hashable, Error.OutputType: Hashable {}

extension CollectedResult: Codable where Output.OutputType: Codable, Error.OutputType: Codable {}

extension CollectedResult: CustomStringConvertible
where Output.OutputType: CustomStringConvertible, Error.OutputType: CustomStringConvertible {
    public var description: String {
        return """
            CollectedResult(
                processIdentifier: \(self.processIdentifier),
                terminationStatus: \(self.terminationStatus.description),
                standardOutput: \(self.standardOutput.description)
                standardError: \(self.standardError.description)
            )
            """
    }
}

extension CollectedResult: CustomDebugStringConvertible
where Output.OutputType: CustomDebugStringConvertible, Error.OutputType: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
            CollectedResult(
                processIdentifier: \(self.processIdentifier),
                terminationStatus: \(self.terminationStatus.description),
                standardOutput: \(self.standardOutput.debugDescription)
                standardError: \(self.standardError.debugDescription)
            )
            """
    }
}

// MARK: - ExecutionResult Conformances
extension ExecutionResult: Equatable where Result: Equatable {}

extension ExecutionResult: Hashable where Result: Hashable {}

extension ExecutionResult: Codable where Result: Codable {}

extension ExecutionResult: CustomStringConvertible where Result: CustomStringConvertible {
    public var description: String {
        return """
            ExecutionResult(
                terminationStatus: \(self.terminationStatus.description),
                value: \(self.value.description)
            )
            """
    }
}

extension ExecutionResult: CustomDebugStringConvertible where Result: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
            ExecutionResult(
                terminationStatus: \(self.terminationStatus.debugDescription),
                value: \(self.value.debugDescription)
            )
            """
    }
}
