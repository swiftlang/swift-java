//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Glibc)

import Glibc
import SystemPackage
import FoundationEssentials
package import _SubprocessCShims

// Linux specific implementations
extension Subprocess.Configuration {
    internal typealias StringOrRawBytes = Subprocess.StringOrRawBytes

    internal func spawn(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput
    ) throws -> Subprocess {
        // Setup signal handler to minitor SIGCHLD
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
    public struct PlatformOptions: Sendable {
        // Set user ID for the subprocess
        public var userID: Int? = nil
        // Set group ID for the subprocess
        public var groupID: Int? = nil
        // Set list of supplementary group IDs for the subprocess
        public var supplementaryGroups: [Int]? = nil
        // Set process group ID for the subprocess
        public var processGroupID: Int? = nil
        // Creates a session and sets the process group ID
        // i.e. Detach from the terminal.
        public var createSession: Bool = false
        // This callback is run after `fork` but before `exec`.
        // Use it to perform any custom process setup
        // This callback *must not* capture any global variables
        public var preSpawnProcessConfigurator: (@convention(c) @Sendable () -> Void)? = nil

        public init(
            userID: Int?,
            groupID: Int?,
            supplementaryGroups: [Int]?,
            processGroupID: Int?,
            createSession: Bool
        ) {
            self.userID = userID
            self.groupID = groupID
            self.supplementaryGroups = supplementaryGroups
            self.processGroupID = processGroupID
            self.createSession = createSession
        }

        public static var `default`: Self {
            return .init(
                userID: nil,
                groupID: nil,
                supplementaryGroups: nil,
                processGroupID: nil,
                createSession: false
            )
        }
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
) async -> Subprocess.TerminationStatus {
    return await withCheckedContinuation { continuation in
        _childProcessContinuations.withLock { continuations in
            if let existing = continuations.removeValue(forKey: pid.value),
               case .status(let existingStatus) = existing {
                // We already have existing status to report
                if _was_process_exited(existingStatus) != 0 {
                    continuation.resume(returning: .exited(_get_exit_code(existingStatus)))
                    return
                }
                if _was_process_signaled(existingStatus) != 0 {
                    continuation.resume(returning: .unhandledException(_get_signal_code(existingStatus)))
                    return
                }
                fatalError("Unexpected exit status type: \(existingStatus)")
            } else {
                // Save the continuation for handler
                continuations[pid.value] = .continuation(continuation)
            }
        }
    }
}

private enum ContinuationOrStatus {
    case continuation(CheckedContinuation<Subprocess.TerminationStatus, Never>)
    case status(Int32)
}

private let _childProcessContinuations: LockedState<
    [pid_t: ContinuationOrStatus]
> = LockedState(initialState: [:])

// Callback for sigaction
private func _childProcessMonitorHandler(_ singnal: Int32) {
    _childProcessContinuations.withLock { continuations in
        var status: Int32 = -1
        let childPid = waitpid(-1, &status, 0)
        if let existing = continuations.removeValue(forKey: childPid),
           case .continuation(let c) = existing {
            // We already have continuations saved
            if _was_process_exited(status) != 0 {
                c.resume(returning: .exited(_get_exit_code(status)))
                return
            }
            if _was_process_signaled(status) != 0 {
                c.resume(returning: .unhandledException(_get_signal_code(status)))
                return
            }
            fatalError("Unexpected exit status type: \(status)")
        } else {
            // We don't have continuation yet, just save the state
            continuations[childPid] = .status(status)
        }
    }
}

private func _setupMonitorSignalHandler() {
    // Only executed once
    let setup = {
        var action: sigaction = sigaction()
        action.__sigaction_handler.sa_handler = _childProcessMonitorHandler
        action.sa_flags = SA_RESTART
        sigemptyset(&action.sa_mask)
        if sigaction(SIGCHLD, &action, nil) != 0 {
            fatalError("Failed to setup signal handler")
        }
    }()
    setup
}

#endif // canImport(Glibc)

