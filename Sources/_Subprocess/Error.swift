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

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#endif

/// Error thrown from Subprocess
public struct SubprocessError: Swift.Error, Hashable, Sendable {
    /// The error code of this error
    public let code: SubprocessError.Code
    /// The underlying error that caused this error, if any
    public let underlyingError: UnderlyingError?
}

// MARK: - Error Codes
extension SubprocessError {
    /// A SubprocessError Code
    public struct Code: Hashable, Sendable {
        internal enum Storage: Hashable, Sendable {
            case spawnFailed
            case executableNotFound(String)
            case failedToChangeWorkingDirectory(String)
            case failedToReadFromSubprocess
            case failedToWriteToSubprocess
            case failedToMonitorProcess
            // Signal
            case failedToSendSignal(Int32)
            // Windows Only
            case failedToTerminate
            case failedToSuspend
            case failedToResume
            case failedToCreatePipe
            case invalidWindowsPath(String)
        }

        public var value: Int {
            switch self.storage {
            case .spawnFailed:
                return 0
            case .executableNotFound(_):
                return 1
            case .failedToChangeWorkingDirectory(_):
                return 2
            case .failedToReadFromSubprocess:
                return 3
            case .failedToWriteToSubprocess:
                return 4
            case .failedToMonitorProcess:
                return 5
            case .failedToSendSignal(_):
                return 6
            case .failedToTerminate:
                return 7
            case .failedToSuspend:
                return 8
            case .failedToResume:
                return 9
            case .failedToCreatePipe:
                return 10
            case .invalidWindowsPath(_):
                return 11
            }
        }

        internal let storage: Storage

        internal init(_ storage: Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Description
extension SubprocessError: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self.code.storage {
        case .spawnFailed:
            return "Failed to spawn the new process."
        case .executableNotFound(let executableName):
            return "Executable \"\(executableName)\" is not found or cannot be executed."
        case .failedToChangeWorkingDirectory(let workingDirectory):
            return "Failed to set working directory to \"\(workingDirectory)\"."
        case .failedToReadFromSubprocess:
            return "Failed to read bytes from the child process with underlying error: \(self.underlyingError!)"
        case .failedToWriteToSubprocess:
            return "Failed to write bytes to the child process."
        case .failedToMonitorProcess:
            return "Failed to monitor the state of child process with underlying error: \(self.underlyingError!)"
        case .failedToSendSignal(let signal):
            return "Failed to send signal \(signal) to the child process."
        case .failedToTerminate:
            return "Failed to terminate the child process."
        case .failedToSuspend:
            return "Failed to suspend the child process."
        case .failedToResume:
            return "Failed to resume the child process."
        case .failedToCreatePipe:
            return "Failed to create a pipe to communicate to child process."
        case .invalidWindowsPath(let badPath):
            return "\"\(badPath)\" is not a valid Windows path."
        }
    }

    public var debugDescription: String { self.description }
}

extension SubprocessError {
    /// The underlying error that caused this SubprocessError.
    /// - On Unix-like systems, `UnderlyingError` wraps `errno` from libc;
    /// - On Windows, `UnderlyingError` wraps Windows Error code
    public struct UnderlyingError: Swift.Error, RawRepresentable, Hashable, Sendable {
        #if os(Windows)
        public typealias RawValue = DWORD
        #else
        public typealias RawValue = Int32
        #endif

        public let rawValue: RawValue

        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}
