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

#if canImport(Darwin) || canImport(Glibc) || canImport(Android) || canImport(Musl)

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

import _SubprocessCShims

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

package import Dispatch

// MARK: - Signals

/// Signals are standardized messages sent to a running program
/// to trigger specific behavior, such as quitting or error handling.
public struct Signal: Hashable, Sendable {
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

// MARK: - ProcessIdentifier

/// A platform independent identifier for a Subprocess.
public struct ProcessIdentifier: Sendable, Hashable, Codable {
    /// The platform specific process identifier value
    public let value: pid_t

    public init(value: pid_t) {
        self.value = value
    }
}

extension ProcessIdentifier: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { "\(self.value)" }

    public var debugDescription: String { "\(self.value)" }
}

@available(macOS 15.0, *) // FIXME: manually added availability
extension Execution {
    /// Send the given signal to the child process.
    /// - Parameters:
    ///   - signal: The signal to send.
    ///   - shouldSendToProcessGroup: Whether this signal should be sent to
    ///     the entire process group.
    public func send(
        signal: Signal,
        toProcessGroup shouldSendToProcessGroup: Bool = false
    ) throws {
        let pid = shouldSendToProcessGroup ? -(self.processIdentifier.value) : self.processIdentifier.value
        guard kill(pid, signal.rawValue) == 0 else {
            throw SubprocessError(
                code: .init(.failedToSendSignal(signal.rawValue)),
                underlyingError: .init(rawValue: errno)
            )
        }
    }

    internal func tryTerminate() -> Swift.Error? {
        do {
            try self.send(signal: .kill)
        } catch {
            guard let posixError: SubprocessError = error as? SubprocessError else {
                return error
            }
            // Ignore ESRCH (no such process)
            if let underlyingError = posixError.underlyingError,
                underlyingError.rawValue != ESRCH
            {
                return error
            }
        }
        return nil
    }
}

// MARK: - Environment Resolution
extension Environment {
    internal static let pathVariableName = "PATH"

    internal func pathValue() -> String? {
        switch self.config {
        case .inherit(let overrides):
            // If PATH value exists in overrides, use it
            if let value = overrides[Self.pathVariableName] {
                return value
            }
            // Fall back to current process
            return Self.currentEnvironmentValues()[Self.pathVariableName]
        case .custom(let fullEnvironment):
            if let value = fullEnvironment[Self.pathVariableName] {
                return value
            }
            return nil
        case .rawBytes(let rawBytesArray):
            let needle: [UInt8] = Array("\(Self.pathVariableName)=".utf8)
            for row in rawBytesArray {
                guard row.starts(with: needle) else {
                    continue
                }
                // Attempt to
                let pathValue = row.dropFirst(needle.count)
                return String(decoding: pathValue, as: UTF8.self)
            }
            return nil
        }
    }

    // This method follows the standard "create" rule: `env` needs to be
    // manually deallocated
    internal func createEnv() -> [UnsafeMutablePointer<CChar>?] {
        func createFullCString(
            fromKey keyContainer: StringOrRawBytes,
            value valueContainer: StringOrRawBytes
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
            var current = Self.currentEnvironmentValues()
            for (key, value) in updates {
                // Remove the value from current to override it
                current.removeValue(forKey: key)
                let fullString = "\(key)=\(value)"
                env.append(strdup(fullString))
            }
            // Add the rest of `current` to env
            for (key, value) in current {
                let fullString = "\(key)=\(value)"
                env.append(strdup(fullString))
            }
        case .custom(let customValues):
            for (key, value) in customValues {
                let fullString = "\(key)=\(value)"
                env.append(strdup(fullString))
            }
        case .rawBytes(let rawBytesArray):
            for rawBytes in rawBytesArray {
                env.append(strdup(rawBytes))
            }
        }
        env.append(nil)
        return env
    }

    internal static func withCopiedEnv<R>(_ body: ([UnsafeMutablePointer<CChar>]) -> R) -> R {
        var values: [UnsafeMutablePointer<CChar>] = []
        // This lock is taken by calls to getenv, so we want as few callouts to other code as possible here.
        _subprocess_lock_environ()
        guard
            let environments: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> =
                _subprocess_get_environ()
        else {
            _subprocess_unlock_environ()
            return body([])
        }
        var curr = environments
        while let value = curr.pointee {
            values.append(strdup(value))
            curr = curr.advanced(by: 1)
        }
        _subprocess_unlock_environ()
        defer { values.forEach { free($0) } }
        return body(values)
    }
}

// MARK: Args Creation
extension Arguments {
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

// MARK: -  Executable Searching
extension Executable {
    internal static var defaultSearchPaths: Set<String> {
        return Set([
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/usr/local/bin",
        ])
    }

    internal func resolveExecutablePath(withPathValue pathValue: String?) throws -> String {
        switch self.storage {
        case .executable(let executableName):
            // If the executableName in is already a full path, return it directly
            if Configuration.pathAccessible(executableName, mode: X_OK) {
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
                let fileExists = Configuration.pathAccessible(fullPath, mode: X_OK)
                if fileExists {
                    return fullPath
                }
            }
            throw SubprocessError(
                code: .init(.executableNotFound(executableName)),
                underlyingError: nil
            )
        case .path(let executablePath):
            // Use path directly
            return executablePath.string
        }
    }
}

// MARK: - PreSpawn
extension Configuration {
    internal typealias PreSpawnArgs = (
        env: [UnsafeMutablePointer<CChar>?],
        uidPtr: UnsafeMutablePointer<uid_t>?,
        gidPtr: UnsafeMutablePointer<gid_t>?,
        supplementaryGroups: [gid_t]?
    )

    internal func preSpawn<Result>(
        _ work: (PreSpawnArgs) throws -> Result
    ) throws -> Result {
        // Prepare environment
        let env = self.environment.createEnv()
        defer {
            for ptr in env { ptr?.deallocate() }
        }

        var uidPtr: UnsafeMutablePointer<uid_t>? = nil
        if let userID = self.platformOptions.userID {
            uidPtr = .allocate(capacity: 1)
            uidPtr?.pointee = userID
        }
        defer {
            uidPtr?.deallocate()
        }
        var gidPtr: UnsafeMutablePointer<gid_t>? = nil
        if let groupID = self.platformOptions.groupID {
            gidPtr = .allocate(capacity: 1)
            gidPtr?.pointee = groupID
        }
        defer {
            gidPtr?.deallocate()
        }
        var supplementaryGroups: [gid_t]?
        if let groupsValue = self.platformOptions.supplementaryGroups {
            supplementaryGroups = groupsValue
        }
        return try work(
            (
                env: env,
                uidPtr: uidPtr,
                gidPtr: gidPtr,
                supplementaryGroups: supplementaryGroups
            )
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

    internal var platformDescriptor: PlatformFileDescriptor {
        return self
    }

    package func readChunk(upToLength maxLength: Int) async throws -> SequenceOutput.Buffer? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchIO.read(
                fromFileDescriptor: self.rawValue,
                maxLength: maxLength,
                runningHandlerOn: .global()
            ) { data, error in
                if error != 0 {
                    continuation.resume(
                        throwing: SubprocessError(
                            code: .init(.failedToReadFromSubprocess),
                            underlyingError: .init(rawValue: error)
                        )
                    )
                    return
                }
                if data.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: SequenceOutput.Buffer(data: data))
                }
            }
        }
    }

    internal func readUntilEOF(
        upToLength maxLength: Int,
        resultHandler: sending @escaping (Swift.Result<DispatchData, any Error>) -> Void
    ) {
        let dispatchIO = DispatchIO(
            type: .stream,
            fileDescriptor: self.rawValue,
            queue: .global()
        ) { error in }
        var buffer: DispatchData?
        dispatchIO.read(
            offset: 0,
            length: maxLength,
            queue: .global()
        ) { done, data, error in
            guard error == 0, let chunkData = data else {
                dispatchIO.close()
                resultHandler(
                    .failure(
                        SubprocessError(
                            code: .init(.failedToReadFromSubprocess),
                            underlyingError: .init(rawValue: error)
                        )
                    )
                )
                return
            }
            // Easy case: if we are done and buffer is nil, this means
            // there is only one chunk of data
            if done && buffer == nil {
                dispatchIO.close()
                buffer = chunkData
                resultHandler(.success(chunkData))
                return
            }

            if buffer == nil {
                buffer = chunkData
            } else {
                buffer?.append(chunkData)
            }

            if done {
                dispatchIO.close()
                resultHandler(.success(buffer!))
                return
            }
        }
    }

    package func write(
        _ array: [UInt8]
    ) async throws -> Int {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, any Error>) in
            let dispatchData = array.withUnsafeBytes {
                return DispatchData(
                    bytesNoCopy: $0,
                    deallocator: .custom(
                        nil,
                        {
                            // noop
                        }
                    )
                )
            }
            self.write(dispatchData) { writtenLength, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: writtenLength)
                }
            }
        }
    }

    package func write(
        _ dispatchData: DispatchData,
        queue: DispatchQueue = .global(),
        completion: @escaping (Int, Error?) -> Void
    ) {
        DispatchIO.write(
            toFileDescriptor: self.rawValue,
            data: dispatchData,
            runningHandlerOn: queue
        ) { unwritten, error in
            let unwrittenLength = unwritten?.count ?? 0
            let writtenLength = dispatchData.count - unwrittenLength
            guard error != 0 else {
                completion(writtenLength, nil)
                return
            }
            completion(
                writtenLength,
                SubprocessError(
                    code: .init(.failedToWriteToSubprocess),
                    underlyingError: .init(rawValue: error)
                )
            )
        }
    }
}

internal typealias PlatformFileDescriptor = FileDescriptor

#endif  // canImport(Darwin) || canImport(Glibc) || canImport(Android) || canImport(Musl)
