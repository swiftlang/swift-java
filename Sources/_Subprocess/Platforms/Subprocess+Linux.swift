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

#if canImport(Glibc)

import Glibc
import Dispatch
import SystemPackage
import FoundationEssentials
import _CShims

// Linux specific implementations
extension Subprocess.Configuration {
    internal typealias StringOrRawBytes = Subprocess.StringOrRawBytes

    internal func spawn(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput
    ) throws -> Subprocess {
        _setupMonitorSignalHandler()

        let (executablePath,
             env, argv,
             intendedWorkingDir,
             uidPtr, gidPtr,
             supplementaryGroups
        ) = try self.preSpawn()
        var processGroupIDPtr: UnsafeMutablePointer<gid_t>? = nil
        if let processGroupID = self.platformOptions.processGroupID {
            processGroupIDPtr = .allocate(capacity: 1)
            processGroupIDPtr?.pointee = gid_t(processGroupID)
        }
        defer {
            for ptr in env { ptr?.deallocate() }
            for ptr in argv { ptr?.deallocate() }
            uidPtr?.deallocate()
            gidPtr?.deallocate()
            processGroupIDPtr?.deallocate()
        }

        let fileDescriptors: [CInt] = [
            input.getReadFileDescriptor()?.rawValue ?? -1,
            input.getWriteFileDescriptor()?.rawValue ?? -1,
            output.getWriteFileDescriptor()?.rawValue ?? -1,
            output.getReadFileDescriptor()?.rawValue ?? -1,
            error.getWriteFileDescriptor()?.rawValue ?? -1,
            error.getReadFileDescriptor()?.rawValue ?? -1
        ]

        var workingDirectory: String?
        if intendedWorkingDir != FilePath.currentWorkingDirectory {
            // Only pass in working directory if it's different
            workingDirectory = intendedWorkingDir.string
        }
        // Spawn
        var pid: pid_t = 0
        let spawnError: CInt = executablePath.withCString { exePath in
            return workingDirectory.withOptionalCString { workingDir in
                return supplementaryGroups.withOptionalUnsafeBufferPointer { sgroups in
                    return fileDescriptors.withUnsafeBufferPointer { fds in
                        return _subprocess_fork_exec(
                            &pid, exePath, workingDir,
                            fds.baseAddress!,
                            argv, env,
                            uidPtr, gidPtr,
                            processGroupIDPtr,
                            CInt(supplementaryGroups?.count ?? 0), sgroups?.baseAddress,
                            self.platformOptions.createSession ? 1 : 0,
                            self.platformOptions.preSpawnProcessConfigurator
                        )
                    }
                }
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

// MARK: - Platform Specific Options
extension Subprocess {
    /// The collection of platform-specific settings
    /// to configure the subprocess when running
    public struct PlatformOptions: Sendable {
        // Set user ID for the subprocess
        public var userID: uid_t? = nil
        /// Set the real and effective group ID and the saved
        /// set-group-ID of the subprocess, equivalent to calling
        /// `setgid()` on the child process.
        /// Group ID is used to control permissions, particularly
        /// for file access.
        public var groupID: gid_t? = nil
        // Set list of supplementary group IDs for the subprocess
        public var supplementaryGroups: [gid_t]? = nil
        /// Set the process group for the subprocess, equivalent to
        /// calling `setpgid()` on the child process.
        /// Process group ID is used to group related processes for
        /// controlling signals.
        public var processGroupID: pid_t? = nil
        // Creates a session and sets the process group ID
        // i.e. Detach from the terminal.
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
        /// On Linux, Subprocess uses `fork/exec` as the
        /// underlying spawning mechanism. This closure is called
        /// after `fork()` but before `exec()`. You may use it to
        /// call any necessary process setup functions.
        public var preSpawnProcessConfigurator: (@convention(c) @Sendable () -> Void)? = nil

        public init() {}
    }
}

extension Subprocess.PlatformOptions: Hashable {
    public static func ==(
        lhs: Subprocess.PlatformOptions,
        rhs: Subprocess.PlatformOptions
    ) -> Bool {
        // Since we can't compare closure equality,
        // as long as preSpawnProcessConfigurator is set
        // always returns false so that `PlatformOptions`
        // with it set will never equal to each other
        if lhs.preSpawnProcessConfigurator != nil ||
            rhs.preSpawnProcessConfigurator != nil {
            return false
        }
        return lhs.userID == rhs.userID &&
            lhs.groupID == rhs.groupID &&
            lhs.supplementaryGroups == rhs.supplementaryGroups &&
            lhs.processGroupID == rhs.processGroupID &&
            lhs.createSession == rhs.createSession
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(userID)
        hasher.combine(groupID)
        hasher.combine(supplementaryGroups)
        hasher.combine(processGroupID)
        hasher.combine(createSession)
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

// Special keys used in Error's user dictionary
extension String {
    static let debugDescriptionErrorKey = "DebugDescription"
}

// MARK: - Process Monitoring
@Sendable
internal func monitorProcessTermination(
    forProcessWithIdentifier pid: Subprocess.ProcessIdentifier
) async throws -> Subprocess.TerminationStatus {
    return try await withCheckedThrowingContinuation { continuation in
        _childProcessContinuations.withLock { continuations in
            if let existing = continuations.removeValue(forKey: pid.value),
               case .status(let existingStatus) = existing {
                // We already have existing status to report
                continuation.resume(returning: existingStatus)
            } else {
                // Save the continuation for handler
                continuations[pid.value] = .continuation(continuation)
            }
        }
    }
}

private enum ContinuationOrStatus {
    case continuation(CheckedContinuation<Subprocess.TerminationStatus, any Error>)
    case status(Subprocess.TerminationStatus)
}

private let _childProcessContinuations: LockedState<
    [pid_t: ContinuationOrStatus]
> = LockedState(initialState: [:])

private var signalSource: (any DispatchSourceSignal)? = nil
private let setup: () = {
    signalSource = DispatchSource.makeSignalSource(
        signal: SIGCHLD,
        queue: .global()
    )
    signalSource?.setEventHandler {
        _childProcessContinuations.withLock { continuations in
            while true {
                var siginfo = siginfo_t()
                guard waitid(P_ALL, id_t(0), &siginfo, WEXITED) == 0 else {
                    return
                }
                var status: Subprocess.TerminationStatus? = nil
                switch siginfo.si_code {
                case .init(CLD_EXITED):
                    status = .exited(siginfo._sifields._sigchld.si_status)
                case .init(CLD_KILLED), .init(CLD_DUMPED):
                    status = .unhandledException(siginfo._sifields._sigchld.si_status)
                case .init(CLD_TRAPPED), .init(CLD_STOPPED), .init(CLD_CONTINUED):
                    // Ignore these signals because they are not related to
                    // process exiting
                    break
                default:
                    fatalError("Unexpected exit status: \(siginfo.si_code)")
                }
                if let status = status {
                    let pid = siginfo._sifields._sigchld.si_pid
                    if let existing = continuations.removeValue(forKey: pid),
                       case .continuation(let c) = existing {
                        c.resume(returning: status)
                    } else {
                        // We don't have continuation yet, just state status
                        continuations[pid] = .status(status)
                    }
                }
            }
        }
    }
    signalSource?.resume()
}()

private func _setupMonitorSignalHandler() {
    // Only executed once
    setup
}

#endif // canImport(Glibc)

