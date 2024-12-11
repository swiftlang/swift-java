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

#if canImport(Darwin) || canImport(Glibc)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _FoundationCShims
#else
import _CShims
#endif

import Dispatch
import SystemPackage

// MARK: - Signals
extension Subprocess {
    /// Signals are standardized messages sent to a running program
    /// to trigger specific behavior, such as quitting or error handling.
    public struct Signal : Hashable, Sendable {
        /// The underlying platform specific value for the signal
        public let rawValue: Int32

        private init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// The `.interrupt` signal is sent to a process by its
        /// controlling terminal when a user wishes to interrupt
        /// the process.
        public static var interrupt: Self { .init(rawValue: SIGINT) }
        /// The `.terminate` signal is sent to a process to request its
        /// termination. Unlike the `.kill` signal, it can be caught
        /// and interpreted or ignored by the process. This allows
        /// the process to perform nice termination releasing resources
        /// and saving state if appropriate. `.interrupt` is nearly
        /// identical to `.terminate`.
        public static var terminate: Self { .init(rawValue: SIGTERM) }
        /// The `.suspend` signal instructs the operating system
        /// to stop a process for later resumption.
        public static var suspend: Self { .init(rawValue: SIGSTOP) }
        /// The `resume` signal instructs the operating system to
        /// continue (restart) a process previously paused by the
        /// `.suspend` signal.
        public static var resume: Self { .init(rawValue: SIGCONT) }
        /// The `.kill` signal is sent to a process to cause it to
        /// terminate immediately (kill). In contrast to `.terminate`
        /// and `.interrupt`, this signal cannot be caught or ignored,
        /// and the receiving process cannot perform any
        /// clean-up upon receiving this signal.
        public static var kill: Self { .init(rawValue: SIGKILL) }
        /// The `.terminalClosed` signal is sent to a process when
        /// its controlling terminal is closed. In modern systems,
        /// this signal usually means that the controlling pseudo
        /// or virtual terminal has been closed.
        public static var terminalClosed: Self { .init(rawValue: SIGHUP) }
        /// The `.quit` signal is sent to a process by its controlling
        /// terminal when the user requests that the process quit
        /// and perform a core dump.
        public static var quit: Self { .init(rawValue: SIGQUIT) }
        /// The `.userDefinedOne` signal is sent to a process to indicate
        /// user-defined conditions.
        public static var userDefinedOne: Self { .init(rawValue: SIGUSR1) }
        /// The `.userDefinedTwo` signal is sent to a process to indicate
        /// user-defined conditions.
        public static var userDefinedTwo: Self { .init(rawValue: SIGUSR2) }
        /// The `.alarm` signal is sent to a process when the corresponding
        /// time limit is reached.
        public static var alarm: Self { .init(rawValue: SIGALRM) }
        /// The `.windowSizeChange` signal is sent to a process when
        /// its controlling terminal changes its size (a window change).
        public static var windowSizeChange: Self { .init(rawValue: SIGWINCH) }
    }

    /// Send the given signal to the child process.
    /// - Parameters:
    ///   - signal: The signal to send.
    ///   - shouldSendToProcessGroup: Whether this signal should be sent to
    ///     the entire process group.
    public func send(_ signal: Signal, toProcessGroup shouldSendToProcessGroup: Bool) throws {
        let pid = shouldSendToProcessGroup ? -(self.processIdentifier.value) : self.processIdentifier.value
        guard kill(pid, signal.rawValue) == 0 else {
            throw POSIXError(.init(rawValue: errno)!)
        }
    }

    internal func tryTerminate() -> Error? {
        do {
            try self.send(.kill, toProcessGroup: true)
        } catch {
            guard let posixError: POSIXError = error as? POSIXError else {
                return error
            }
            // Ignore ESRCH (no such process)
            if posixError.code != .ESRCH {
                return error
            }
        }
        return nil
    }
}

// MARK: - Environment Resolution
extension Subprocess.Environment {
    internal static let pathEnvironmentVariableName = "PATH"

    internal func pathValue() -> String? {
        switch self.config {
        case .inherit(let overrides):
            // If PATH value exists in overrides, use it
            if let value = overrides[.string(Self.pathEnvironmentVariableName)] {
                return value.stringValue
            }
            // Fall back to current process
            return ProcessInfo.processInfo.environment[Self.pathEnvironmentVariableName]
        case .custom(let fullEnvironment):
            if let value = fullEnvironment[.string(Self.pathEnvironmentVariableName)] {
                return value.stringValue
            }
            return nil
        }
    }

    // This method follows the standard "create" rule: `env` needs to be
    // manually deallocated
    internal func createEnv() -> [UnsafeMutablePointer<CChar>?] {
        func createFullCString(
            fromKey keyContainer: Subprocess.StringOrRawBytes,
            value valueContainer: Subprocess.StringOrRawBytes
        ) -> UnsafeMutablePointer<CChar> {
            let rawByteKey: UnsafeMutablePointer<CChar> = keyContainer.createRawBytes()
            let rawByteValue: UnsafeMutablePointer<CChar> = valueContainer.createRawBytes()
            defer {
                rawByteKey.deallocate()
                rawByteValue.deallocate()
            }
            /// length = `key` + `=` + `value` + `\null`
            let totalLength = keyContainer.count + 1 + valueContainer.count + 1
            let fullString: UnsafeMutablePointer<CChar> = .allocate(capacity: totalLength)
            #if canImport(Darwin)
            _ = snprintf(ptr: fullString, totalLength, "%s=%s", rawByteKey, rawByteValue)
            #else
            _ = _shims_snprintf(fullString, CInt(totalLength), "%s=%s", rawByteKey, rawByteValue)
            #endif
            return fullString
        }

        var env: [UnsafeMutablePointer<CChar>?] = []
        switch self.config {
        case .inherit(let updates):
            var current = ProcessInfo.processInfo.environment
            for (keyContainer, valueContainer) in updates {
                if let stringKey = keyContainer.stringValue {
                    // Remove the value from current to override it
                    current.removeValue(forKey: stringKey)
                }
                // Fast path
                if case .string(let stringKey) = keyContainer,
                   case .string(let stringValue) = valueContainer {
                    let fullString = "\(stringKey)=\(stringValue)"
                    env.append(strdup(fullString))
                    continue
                }

                env.append(createFullCString(fromKey: keyContainer, value: valueContainer))
            }
            // Add the rest of `current` to env
            for (key, value) in current {
                let fullString = "\(key)=\(value)"
                env.append(strdup(fullString))
            }
        case .custom(let customValues):
            for (keyContainer, valueContainer) in customValues {
                // Fast path
                if case .string(let stringKey) = keyContainer,
                   case .string(let stringValue) = valueContainer {
                    let fullString = "\(stringKey)=\(stringValue)"
                    env.append(strdup(fullString))
                    continue
                }
                env.append(createFullCString(fromKey: keyContainer, value: valueContainer))
            }
        }
        env.append(nil)
        return env
    }
}

// MARK: Args Creation
extension Subprocess.Arguments {
    // This method follows the standard "create" rule: `args` needs to be
    // manually deallocated
    internal func createArgs(withExecutablePath executablePath: String) -> [UnsafeMutablePointer<CChar>?] {
        var argv: [UnsafeMutablePointer<CChar>?] = self.storage.map { $0.createRawBytes() }
        // argv[0] = executable path
        if let override = self.executablePathOverride {
            argv.insert(override.createRawBytes(), at: 0)
        } else {
            argv.insert(strdup(executablePath), at: 0)
        }
        argv.append(nil)
        return argv
    }
}

// MARK: - ProcessIdentifier
extension Subprocess {
    /// A platform independent identifier for a subprocess.
    public struct ProcessIdentifier: Sendable, Hashable, Codable {
        /// The platform specific process identifier value
        public let value: pid_t

        public init(value: pid_t) {
            self.value = value
        }
    }
}

extension Subprocess.ProcessIdentifier : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { "\(self.value)" }

    public var debugDescription: String { "\(self.value)" }
}

// MARK: -  Executable Searching
extension Subprocess.Executable {
    internal static var defaultSearchPaths: Set<String> {
        return Set([
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/usr/local/bin"
        ])
    }

    internal func resolveExecutablePath(withPathValue pathValue: String?) -> String? {
        switch self.storage {
        case .executable(let executableName):
            // If the executableName in is already a full path, return it directly
            if Subprocess.Configuration.pathAccessible(executableName, mode: X_OK) {
                return executableName
            }
            // Get $PATH from environment
            let searchPaths: Set<String>
            if let pathValue = pathValue {
                let localSearchPaths = pathValue.split(separator: ":").map { String($0) }
                searchPaths = Set(localSearchPaths).union(Self.defaultSearchPaths)
            } else {
                searchPaths = Self.defaultSearchPaths
            }

            for path in searchPaths {
                let fullPath = "\(path)/\(executableName)"
                let fileExists = Subprocess.Configuration.pathAccessible(fullPath, mode: X_OK)
                if fileExists {
                    return fullPath
                }
            }
        case .path(let executablePath):
            // Use path directly
            return executablePath.string
        }
        return nil
    }
}

// MARK: - Configuration
extension Subprocess.Configuration {
    internal func preSpawn() throws -> (
        executablePath: String,
        env: [UnsafeMutablePointer<CChar>?],
        argv: [UnsafeMutablePointer<CChar>?],
        intendedWorkingDir: FilePath,
        uidPtr: UnsafeMutablePointer<uid_t>?,
        gidPtr: UnsafeMutablePointer<gid_t>?,
        supplementaryGroups: [gid_t]?
    ) {
        // Prepare environment
        let env = self.environment.createEnv()
        // Prepare executable path
        guard let executablePath = self.executable.resolveExecutablePath(
            withPathValue: self.environment.pathValue()) else {
            for ptr in env { ptr?.deallocate() }
            throw CocoaError(.executableNotLoadable, userInfo: [
                .debugDescriptionErrorKey : "\(self.executable.description) is not an executable"
            ])
        }
        // Prepare arguments
        let argv: [UnsafeMutablePointer<CChar>?] = self.arguments.createArgs(withExecutablePath: executablePath)
        // Prepare workingDir
        let intendedWorkingDir = self.workingDirectory
        guard Self.pathAccessible(intendedWorkingDir.string, mode: F_OK) else {
            for ptr in env { ptr?.deallocate() }
            for ptr in argv { ptr?.deallocate() }
            throw CocoaError(.fileNoSuchFile, userInfo: [
                .debugDescriptionErrorKey : "Failed to set working directory to \(intendedWorkingDir)"
            ])
        }

        var uidPtr: UnsafeMutablePointer<uid_t>? = nil
        if let userID = self.platformOptions.userID {
            uidPtr = .allocate(capacity: 1)
            uidPtr?.pointee = userID
        }
        var gidPtr: UnsafeMutablePointer<gid_t>? = nil
        if let groupID = self.platformOptions.groupID {
            gidPtr = .allocate(capacity: 1)
            gidPtr?.pointee = groupID
        }
        var supplementaryGroups: [gid_t]?
        if let groupsValue = self.platformOptions.supplementaryGroups {
            supplementaryGroups = groupsValue
        }
        return (
            executablePath: executablePath,
            env: env, argv: argv,
            intendedWorkingDir: intendedWorkingDir,
            uidPtr: uidPtr, gidPtr: gidPtr,
            supplementaryGroups: supplementaryGroups
        )
    }

    internal static func pathAccessible(_ path: String, mode: Int32) -> Bool {
        return path.withCString {
            return access($0, mode) == 0
        }
    }
}

// MARK: - FileDescriptor extensions
extension FileDescriptor {
    internal static func openDevNull(
        withAcessMode mode: FileDescriptor.AccessMode
    ) throws -> FileDescriptor {
        let devnull: FileDescriptor = try .open("/dev/null", mode)
        return devnull
    }

    internal var platformDescriptor: Subprocess.PlatformFileDescriptor {
        return self
    }

    internal func readChunk(upToLength maxLength: Int) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchIO.read(
                fromFileDescriptor: self.rawValue,
                maxLength: maxLength,
                runningHandlerOn: .global()
            ) { data, error in
                if error != 0 {
                    continuation.resume(throwing: POSIXError(.init(rawValue: error) ?? .ENODEV))
                    return
                }
                if data.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: Data(data))
                }
            }
        }
    }

    internal func readUntilEOF(upToLength maxLength: Int) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let dispatchIO = DispatchIO(
                type: .stream,
                fileDescriptor: self.rawValue,
                queue: .global()
            ) { error in
                if error != 0 {
                    continuation.resume(throwing: POSIXError(.init(rawValue: error) ?? .ENODEV))
                }
            }
            var buffer: Data = Data()
            dispatchIO.read(
                offset: 0,
                length: maxLength,
                queue: .global()
            ) { done, data, error in
                guard error == 0 else {
                    continuation.resume(throwing: POSIXError(.init(rawValue: error) ?? .ENODEV))
                    return
                }
                if let data = data {
                    buffer += Data(data)
                }
                if done {
                    dispatchIO.close()
                    continuation.resume(returning: buffer)
                }
            }
        }
    }

    internal func write<S: Sequence>(_ data: S) async throws where S.Element == UInt8 {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            let dispatchData: DispatchData = Array(data).withUnsafeBytes {
                return DispatchData(bytes: $0)
            }
            DispatchIO.write(
                toFileDescriptor: self.rawValue,
                data: dispatchData,
                runningHandlerOn: .global()
            ) { _, error in
                guard error == 0 else {
                    continuation.resume(
                        throwing: POSIXError(
                            .init(rawValue: error) ?? .ENODEV)
                    )
                    return
                }
                continuation.resume()
            }
        }
    }
}

extension Subprocess {
    internal typealias PlatformFileDescriptor = FileDescriptor
}

// MARK: - Read Buffer Size
extension Subprocess {
    @inline(__always)
    internal static var readBufferSize: Int {
#if canImport(Darwin)
        return 16384
#else
        // FIXME: Use Platform.pageSize here
        return 4096
#endif // canImport(Darwin)
    }
}

#endif // canImport(Darwin) || canImport(Glibc)
