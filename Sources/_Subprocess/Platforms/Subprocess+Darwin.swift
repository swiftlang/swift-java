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

#if canImport(Darwin)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

import Darwin
import Dispatch
import SystemPackage

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _FoundationCShims
#else
import _CShims
#endif

// Darwin specific implementation
extension Subprocess.Configuration {
    internal typealias StringOrRawBytes = Subprocess.StringOrRawBytes

    internal func spawn(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput
    ) throws -> Subprocess {
        let (executablePath,
            env, argv,
            intendedWorkingDir,
            uidPtr, gidPtr, supplementaryGroups
        ) = try self.preSpawn()
        defer {
            for ptr in env { ptr?.deallocate() }
            for ptr in argv { ptr?.deallocate() }
            uidPtr?.deallocate()
            gidPtr?.deallocate()
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
        if let inputRead = input.getReadFileDescriptor() {
            result = posix_spawn_file_actions_adddup2(&fileActions, inputRead.rawValue, 0)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        if let inputWrite = input.getWriteFileDescriptor() {
            // Close parent side
            result = posix_spawn_file_actions_addclose(&fileActions, inputWrite.rawValue)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        // Output
        if let outputWrite = output.getWriteFileDescriptor() {
            result = posix_spawn_file_actions_adddup2(&fileActions, outputWrite.rawValue, 1)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        if let outputRead = output.getReadFileDescriptor() {
            // Close parent side
            result = posix_spawn_file_actions_addclose(&fileActions, outputRead.rawValue)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        // Error
        if let errorWrite = error.getWriteFileDescriptor() {
            result = posix_spawn_file_actions_adddup2(&fileActions, errorWrite.rawValue, 2)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        if let errorRead = error.getReadFileDescriptor() {
            // Close parent side
            result = posix_spawn_file_actions_addclose(&fileActions, errorRead.rawValue)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
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
        var flags: Int32 = POSIX_SPAWN_CLOEXEC_DEFAULT |
            POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
        if let pgid = self.platformOptions.processGroupID {
            flags |= POSIX_SPAWN_SETPGROUP
            spawnAttributeError = posix_spawnattr_setpgroup(&spawnAttributes, pid_t(pgid))
        }
        spawnAttributeError = posix_spawnattr_setflags(&spawnAttributes, Int16(flags))
        // Set QualityOfService
        // spanattr_qos seems to only accept `QOS_CLASS_UTILITY` or `QOS_CLASS_BACKGROUND`
        // and returns an error of `EINVAL` if anything else is provided
        if spawnAttributeError == 0 && self.platformOptions.qualityOfService == .utility{
            spawnAttributeError = posix_spawnattr_set_qos_class_np(&spawnAttributes, QOS_CLASS_UTILITY)
        } else if spawnAttributeError == 0 && self.platformOptions.qualityOfService == .background {
            spawnAttributeError = posix_spawnattr_set_qos_class_np(&spawnAttributes, QOS_CLASS_BACKGROUND)
        }

        // Setup cwd
        var chdirError: Int32 = 0
        if intendedWorkingDir != .currentWorkingDirectory {
            chdirError = intendedWorkingDir.withPlatformString { workDir in
                return posix_spawn_file_actions_addchdir_np(&fileActions, workDir)
            }
        }

        // Error handling
        if chdirError != 0 || spawnAttributeError != 0 {
            try self.cleanupAll(input: input, output: output, error: error)
            if spawnAttributeError != 0 {
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }

            if chdirError != 0 {
                throw CocoaError(.fileNoSuchFile, userInfo: [
                    .debugDescriptionErrorKey: "Cannot failed to change the working directory to \(intendedWorkingDir) with errno \(chdirError)"
                ])
            }
        }
        // Run additional config
        if let spawnConfig = self.platformOptions.preSpawnProcessConfigurator {
            try spawnConfig(&spawnAttributes, &fileActions)
        }
        // Spawn
        var pid: pid_t = 0
        let spawnError: CInt = executablePath.withCString { exePath in
            return supplementaryGroups.withOptionalUnsafeBufferPointer { sgroups in
                return _subprocess_spawn(
                    &pid, exePath,
                    &fileActions, &spawnAttributes,
                    argv, env,
                    uidPtr, gidPtr,
                    Int32(supplementaryGroups?.count ?? 0), sgroups?.baseAddress,
                    self.platformOptions.createSession ? 1 : 0
                )
            }
        }
        // Spawn error
        if spawnError != 0 {
            try self.cleanupAll(input: input, output: output, error: error)
            throw POSIXError(.init(rawValue: spawnError) ?? .ENODEV)
        }
        return Subprocess(
            processIdentifier: .init(value: pid),
            executionInput: input,
            executionOutput: output,
            executionError: error
        )
    }
}

// Special keys used in Error's user dictionary
extension String {
    static let debugDescriptionErrorKey = "NSDebugDescription"
}

// MARK: - Platform Specific Options
extension Subprocess {
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
        /// A lightweight code requirement that you use to
        /// evaluate the executable for a launching process.
        public var launchRequirementData: Data? = nil
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
        public var preSpawnProcessConfigurator: (
            @Sendable (
                inout posix_spawnattr_t?,
                inout posix_spawn_file_actions_t?
            ) throws -> Void
        )? = nil

        public init() {}
    }
}

extension Subprocess.PlatformOptions: Hashable {
    public static func == (lhs: Subprocess.PlatformOptions, rhs: Subprocess.PlatformOptions) -> Bool {
        // Since we can't compare closure equality,
        // as long as preSpawnProcessConfigurator is set
        // always returns false so that `PlatformOptions`
        // with it set will never equal to each other
        if lhs.preSpawnProcessConfigurator != nil ||
            rhs.preSpawnProcessConfigurator != nil {
            return false
        }
        return lhs.qualityOfService == rhs.qualityOfService &&
            lhs.userID == rhs.userID &&
            lhs.groupID == rhs.groupID &&
            lhs.supplementaryGroups == rhs.supplementaryGroups &&
            lhs.processGroupID == rhs.processGroupID &&
            lhs.createSession == rhs.createSession &&
            lhs.launchRequirementData == rhs.launchRequirementData
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.qualityOfService)
        hasher.combine(self.userID)
        hasher.combine(self.groupID)
        hasher.combine(self.supplementaryGroups)
        hasher.combine(self.processGroupID)
        hasher.combine(self.createSession)
        hasher.combine(self.launchRequirementData)
        // Since we can't really hash closures,
        // use an UUID such that as long as
        // `preSpawnProcessConfigurator` is set, it will
        // never equal to other PlatformOptions
        if self.preSpawnProcessConfigurator != nil {
            hasher.combine(UUID())
        }
    }
}

extension Subprocess.PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {
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
\(indent)    launchRequirementData: \(String(describing: launchRequirementData)),
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

// MARK: - Process Monitoring
@Sendable
internal func monitorProcessTermination(
    forProcessWithIdentifier pid: Subprocess.ProcessIdentifier
) async throws -> Subprocess.TerminationStatus {
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
                continuation.resume(throwing: POSIXError(.init(rawValue: errno) ?? .ENODEV))
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

#endif // canImport(Darwin)
