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
internal import Dispatch
#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

import _SubprocessCShims

#if SubprocessFoundation

#if canImport(Darwin)
// On Darwin always prefer system Foundation
import Foundation
#else
// On other platforms prefer FoundationEssentials
import FoundationEssentials
#endif

#endif  // SubprocessFoundation

// MARK: - PlatformOptions

/// The collection of platform-specific settings
/// to configure the subprocess when running
public struct PlatformOptions: Sendable {
    public var qualityOfService: QualityOfService = .default
    /// Set user ID for the subprocess
    public var userID: uid_t? = nil
    /// Set the real and effective group ID and the saved
    /// set-group-ID of the subprocess, equivalent to calling
    /// `setgid()` on the child process.
    /// Group ID is used to control permissions, particularly
    /// for file access.
    public var groupID: gid_t? = nil
    /// Set list of supplementary group IDs for the subprocess
    public var supplementaryGroups: [gid_t]? = nil
    /// Set the process group for the subprocess, equivalent to
    /// calling `setpgid()` on the child process.
    /// Process group ID is used to group related processes for
    /// controlling signals.
    public var processGroupID: pid_t? = nil
    /// Creates a session and sets the process group ID
    /// i.e. Detach from the terminal.
    public var createSession: Bool = false
    /// An ordered list of steps in order to tear down the child
    /// process in case the parent task is cancelled before
    /// the child proces terminates.
    /// Always ends in sending a `.kill` signal at the end.
    public var teardownSequence: [TeardownStep] = []
    /// A closure to configure platform-specific
    /// spawning constructs. This closure enables direct
    /// configuration or override of underlying platform-specific
    /// spawn settings that `Subprocess` utilizes internally,
    /// in cases where Subprocess does not provide higher-level
    /// APIs for such modifications.
    ///
    /// On Darwin, Subprocess uses `posix_spawn()` as the
    /// underlying spawning mechanism. This closure allows
    /// modification of the `posix_spawnattr_t` spawn attribute
    /// and file actions `posix_spawn_file_actions_t` before
    /// they are sent to `posix_spawn()`.
    public var preSpawnProcessConfigurator:
        (
            @Sendable (
                inout posix_spawnattr_t?,
                inout posix_spawn_file_actions_t?
            ) throws -> Void
        )? = nil

    public init() {}
}

extension PlatformOptions {
    #if SubprocessFoundation
    public typealias QualityOfService = Foundation.QualityOfService
    #else
    /// Constants that indicate the nature and importance of work to the system.
    ///
    /// Work with higher quality of service classes receive more resources
    /// than work with lower quality of service classes whenever
    /// there’s resource contention.
    public enum QualityOfService: Int, Sendable {
        /// Used for work directly involved in providing an
        /// interactive UI. For example, processing control
        /// events or drawing to the screen.
        case userInteractive = 0x21
        /// Used for performing work that has been explicitly requested
        /// by the user, and for which results must be immediately
        /// presented in order to allow for further user interaction.
        /// For example, loading an email after a user has selected
        /// it in a message list.
        case userInitiated = 0x19
        /// Used for performing work which the user is unlikely to be
        /// immediately waiting for the results. This work may have been
        /// requested by the user or initiated automatically, and often
        /// operates at user-visible timescales using a non-modal
        /// progress indicator. For example, periodic content updates
        /// or bulk file operations, such as media import.
        case utility = 0x11
        /// Used for work that is not user initiated or visible.
        /// In general, a user is unaware that this work is even happening.
        /// For example, pre-fetching content, search indexing, backups,
        /// or syncing of data with external systems.
        case background = 0x09
        /// Indicates no explicit quality of service information.
        /// Whenever possible, an appropriate quality of service is determined
        /// from available sources. Otherwise, some quality of service level
        /// between `.userInteractive` and `.utility` is used.
        case `default` = -1
    }
    #endif
}

extension PlatformOptions: CustomStringConvertible, CustomDebugStringConvertible {
    internal func description(withIndent indent: Int) -> String {
        let indent = String(repeating: " ", count: indent * 4)
        return """
            PlatformOptions(
            \(indent)    qualityOfService: \(self.qualityOfService),
            \(indent)    userID: \(String(describing: userID)),
            \(indent)    groupID: \(String(describing: groupID)),
            \(indent)    supplementaryGroups: \(String(describing: supplementaryGroups)),
            \(indent)    processGroupID: \(String(describing: processGroupID)),
            \(indent)    createSession: \(createSession),
            \(indent)    preSpawnProcessConfigurator: \(self.preSpawnProcessConfigurator == nil ? "not set" : "set")
            \(indent))
            """
    }

    public var description: String {
        return self.description(withIndent: 0)
    }

    public var debugDescription: String {
        return self.description(withIndent: 0)
    }
}

// MARK: - Spawn
extension Configuration {
    @available(macOS 15.0, *) // FIXME: manually added availability
    internal func spawn<
        Output: OutputProtocol,
        Error: OutputProtocol
    >(
        withInput inputPipe: CreatedPipe,
        output: Output,
        outputPipe: CreatedPipe,
        error: Error,
        errorPipe: CreatedPipe
    ) throws -> Execution<Output, Error> {
        // Instead of checking if every possible executable path
        // is valid, spawn each directly and catch ENOENT
        let possiblePaths = self.executable.possibleExecutablePaths(
            withPathValue: self.environment.pathValue()
        )
        return try self.preSpawn { args throws -> Execution<Output, Error> in
            let (env, uidPtr, gidPtr, supplementaryGroups) = args
            for possibleExecutablePath in possiblePaths {
                var pid: pid_t = 0

                // Setup Arguments
                let argv: [UnsafeMutablePointer<CChar>?] = self.arguments.createArgs(
                    withExecutablePath: possibleExecutablePath
                )
                defer {
                    for ptr in argv { ptr?.deallocate() }
                }

                // Setup file actions and spawn attributes
                var fileActions: posix_spawn_file_actions_t? = nil
                var spawnAttributes: posix_spawnattr_t? = nil
                // Setup stdin, stdout, and stderr
                posix_spawn_file_actions_init(&fileActions)
                defer {
                    posix_spawn_file_actions_destroy(&fileActions)
                }
                // Input
                var result: Int32 = -1
                if let inputRead = inputPipe.readFileDescriptor {
                    result = posix_spawn_file_actions_adddup2(&fileActions, inputRead.wrapped.rawValue, 0)
                    guard result == 0 else {
                        try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: result)
                        )
                    }
                }
                if let inputWrite = inputPipe.writeFileDescriptor {
                    // Close parent side
                    result = posix_spawn_file_actions_addclose(&fileActions, inputWrite.wrapped.rawValue)
                    guard result == 0 else {
                        try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: result)
                        )
                    }
                }
                // Output
                if let outputWrite = outputPipe.writeFileDescriptor {
                    result = posix_spawn_file_actions_adddup2(&fileActions, outputWrite.wrapped.rawValue, 1)
                    guard result == 0 else {
                        try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: result)
                        )
                    }
                }
                if let outputRead = outputPipe.readFileDescriptor {
                    // Close parent side
                    result = posix_spawn_file_actions_addclose(&fileActions, outputRead.wrapped.rawValue)
                    guard result == 0 else {
                        try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: result)
                        )
                    }
                }
                // Error
                if let errorWrite = errorPipe.writeFileDescriptor {
                    result = posix_spawn_file_actions_adddup2(&fileActions, errorWrite.wrapped.rawValue, 2)
                    guard result == 0 else {
                        try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: result)
                        )
                    }
                }
                if let errorRead = errorPipe.readFileDescriptor {
                    // Close parent side
                    result = posix_spawn_file_actions_addclose(&fileActions, errorRead.wrapped.rawValue)
                    guard result == 0 else {
                        try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: result)
                        )
                    }
                }
                // Setup spawnAttributes
                posix_spawnattr_init(&spawnAttributes)
                defer {
                    posix_spawnattr_destroy(&spawnAttributes)
                }
                var noSignals = sigset_t()
                var allSignals = sigset_t()
                sigemptyset(&noSignals)
                sigfillset(&allSignals)
                posix_spawnattr_setsigmask(&spawnAttributes, &noSignals)
                posix_spawnattr_setsigdefault(&spawnAttributes, &allSignals)
                // Configure spawnattr
                var spawnAttributeError: Int32 = 0
                var flags: Int32 = POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
                if let pgid = self.platformOptions.processGroupID {
                    flags |= POSIX_SPAWN_SETPGROUP
                    spawnAttributeError = posix_spawnattr_setpgroup(&spawnAttributes, pid_t(pgid))
                }
                spawnAttributeError = posix_spawnattr_setflags(&spawnAttributes, Int16(flags))
                // Set QualityOfService
                // spanattr_qos seems to only accept `QOS_CLASS_UTILITY` or `QOS_CLASS_BACKGROUND`
                // and returns an error of `EINVAL` if anything else is provided
                if spawnAttributeError == 0 && self.platformOptions.qualityOfService == .utility {
                    spawnAttributeError = posix_spawnattr_set_qos_class_np(&spawnAttributes, QOS_CLASS_UTILITY)
                } else if spawnAttributeError == 0 && self.platformOptions.qualityOfService == .background {
                    spawnAttributeError = posix_spawnattr_set_qos_class_np(&spawnAttributes, QOS_CLASS_BACKGROUND)
                }

                // Setup cwd
                let intendedWorkingDir = self.workingDirectory.string
                let chdirError: Int32 = intendedWorkingDir.withPlatformString { workDir in
                    return posix_spawn_file_actions_addchdir_np(&fileActions, workDir)
                }

                // Error handling
                if chdirError != 0 || spawnAttributeError != 0 {
                    try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
                    if spawnAttributeError != 0 {
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: spawnAttributeError)
                        )
                    }

                    if chdirError != 0 {
                        throw SubprocessError(
                            code: .init(.spawnFailed),
                            underlyingError: .init(rawValue: spawnAttributeError)
                        )
                    }
                }
                // Run additional config
                if let spawnConfig = self.platformOptions.preSpawnProcessConfigurator {
                    try spawnConfig(&spawnAttributes, &fileActions)
                }

                // Spawn
                let spawnError: CInt = possibleExecutablePath.withCString { exePath in
                    return supplementaryGroups.withOptionalUnsafeBufferPointer { sgroups in
                        return _subprocess_spawn(
                            &pid,
                            exePath,
                            &fileActions,
                            &spawnAttributes,
                            argv,
                            env,
                            uidPtr,
                            gidPtr,
                            Int32(supplementaryGroups?.count ?? 0),
                            sgroups?.baseAddress,
                            self.platformOptions.createSession ? 1 : 0
                        )
                    }
                }
                // Spawn error
                if spawnError != 0 {
                    if spawnError == ENOENT {
                        // Move on to another possible path
                        continue
                    }
                    // Throw all other errors
                    try self.cleanupPreSpawn(
                        input: inputPipe,
                        output: outputPipe,
                        error: errorPipe
                    )
                    throw SubprocessError(
                        code: .init(.spawnFailed),
                        underlyingError: .init(rawValue: spawnError)
                    )
                }
                return Execution(
                    processIdentifier: .init(value: pid),
                    output: output,
                    error: error,
                    outputPipe: outputPipe,
                    errorPipe: errorPipe
                )
            }

            // If we reach this point, it means either the executable path
            // or working directory is not valid. Since posix_spawn does not
            // provide which one is not valid, here we make a best effort guess
            // by checking whether the working directory is valid. This technically
            // still causes TOUTOC issue, but it's the best we can do for error recovery.
            try self.cleanupPreSpawn(input: inputPipe, output: outputPipe, error: errorPipe)
            let workingDirectory = self.workingDirectory.string
            guard Configuration.pathAccessible(workingDirectory, mode: F_OK) else {
                throw SubprocessError(
                    code: .init(.failedToChangeWorkingDirectory(workingDirectory)),
                    underlyingError: .init(rawValue: ENOENT)
                )
            }
            throw SubprocessError(
                code: .init(.executableNotFound(self.executable.description)),
                underlyingError: .init(rawValue: ENOENT)
            )
        }
    }
}

// Special keys used in Error's user dictionary
extension String {
    static let debugDescriptionErrorKey = "NSDebugDescription"
}

// MARK: - Process Monitoring
@Sendable
internal func monitorProcessTermination(
    forProcessWithIdentifier pid: ProcessIdentifier
) async throws -> TerminationStatus {
    return try await withCheckedThrowingContinuation { continuation in
        let source = DispatchSource.makeProcessSource(
            identifier: pid.value,
            eventMask: [.exit],
            queue: .global()
        )
        source.setEventHandler {
            source.cancel()
            var siginfo = siginfo_t()
            let rc = waitid(P_PID, id_t(pid.value), &siginfo, WEXITED)
            guard rc == 0 else {
                continuation.resume(
                    throwing: SubprocessError(
                        code: .init(.failedToMonitorProcess),
                        underlyingError: .init(rawValue: errno)
                    )
                )
                return
            }
            switch siginfo.si_code {
            case .init(CLD_EXITED):
                continuation.resume(returning: .exited(siginfo.si_status))
                return
            case .init(CLD_KILLED), .init(CLD_DUMPED):
                continuation.resume(returning: .unhandledException(siginfo.si_status))
            case .init(CLD_TRAPPED), .init(CLD_STOPPED), .init(CLD_CONTINUED), .init(CLD_NOOP):
                // Ignore these signals because they are not related to
                // process exiting
                break
            default:
                fatalError("Unexpected exit status: \(siginfo.si_code)")
            }
        }
        source.resume()
    }
}

#endif  // canImport(Darwin)
