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

import _SubprocessCShims

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#endif

/// A step in the graceful shutdown teardown sequence.
/// It consists of an action to perform on the child process and the
/// duration allowed for the child process to exit before proceeding
/// to the next step.
public struct TeardownStep: Sendable, Hashable {
    internal enum Storage: Sendable, Hashable {
        #if !os(Windows)
        case sendSignal(Signal, allowedDuration: Duration)
        #endif
        case gracefulShutDown(allowedDuration: Duration)
        case kill
    }
    var storage: Storage

    #if !os(Windows)
    /// Sends `signal` to the process and allows `allowedDurationToExit`
    /// for the process to exit before proceeding to the next step.
    /// The final step in the sequence will always send a `.kill` signal.
    public static func send(
        signal: Signal,
        allowedDurationToNextStep: Duration
    ) -> Self {
        return Self(
            storage: .sendSignal(
                signal,
                allowedDuration: allowedDurationToNextStep
            )
        )
    }
    #endif  // !os(Windows)

    /// Attempt to perform a graceful shutdown and allows
    /// `allowedDurationToNextStep` for the process to exit
    /// before proceeding to the next step:
    /// - On Unix: send `SIGTERM`
    /// - On Windows:
    ///   1. Attempt to send `VM_CLOSE` if the child process is a GUI process;
    ///   2. Attempt to send `CTRL_C_EVENT` to console;
    ///   3. Attempt to send `CTRL_BREAK_EVENT` to process group.
    public static func gracefulShutDown(
        allowedDurationToNextStep: Duration
    ) -> Self {
        return Self(
            storage: .gracefulShutDown(
                allowedDuration: allowedDurationToNextStep
            )
        )
    }
}

@available(macOS 15.0, *) // FIXME: manually added availability
extension Execution {
    /// Performs a sequence of teardown steps on the Subprocess.
    /// Teardown sequence always ends with a `.kill` signal
    /// - Parameter sequence: The  steps to perform.
    public func teardown(using sequence: some Sequence<TeardownStep> & Sendable) async {
        await withUncancelledTask {
            await self.runTeardownSequence(sequence)
        }
    }
}

internal enum TeardownStepCompletion {
    case processHasExited
    case processStillAlive
    case killedTheProcess
}

@available(macOS 15.0, *) // FIXME: manually added availability
extension Execution {
    internal func gracefulShutDown(
        allowedDurationToNextStep duration: Duration
    ) async {
        #if os(Windows)
        guard
            let processHandle = OpenProcess(
                DWORD(PROCESS_QUERY_INFORMATION | SYNCHRONIZE),
                false,
                self.processIdentifier.value
            )
        else {
            // Nothing more we can do
            return
        }
        defer {
            CloseHandle(processHandle)
        }

        // 1. Attempt to send WM_CLOSE to the main window
        if _subprocess_windows_send_vm_close(
            self.processIdentifier.value
        ) {
            try? await Task.sleep(for: duration)
        }

        // 2. Attempt to attach to the console and send CTRL_C_EVENT
        if AttachConsole(self.processIdentifier.value) {
            // Disable Ctrl-C handling in this process
            if SetConsoleCtrlHandler(nil, true) {
                if GenerateConsoleCtrlEvent(DWORD(CTRL_C_EVENT), 0) {
                    // We successfully sent the event. wait for the process to exit
                    try? await Task.sleep(for: duration)
                }
                // Re-enable Ctrl-C handling
                SetConsoleCtrlHandler(nil, false)
            }
            // Detach console
            FreeConsole()
        }

        // 3. Attempt to send CTRL_BREAK_EVENT to the process group
        if GenerateConsoleCtrlEvent(DWORD(CTRL_BREAK_EVENT), self.processIdentifier.value) {
            // Wait for process to exit
            try? await Task.sleep(for: duration)
        }
        #else
        // Send SIGTERM
        try? self.send(signal: .terminate)
        #endif
    }

    internal func runTeardownSequence(_ sequence: some Sequence<TeardownStep> & Sendable) async {
        // First insert the `.kill` step
        let finalSequence = sequence + [TeardownStep(storage: .kill)]
        for step in finalSequence {
            let stepCompletion: TeardownStepCompletion

            switch step.storage {
            case .gracefulShutDown(let allowedDuration):
                stepCompletion = await withTaskGroup(of: TeardownStepCompletion.self) { group in
                    group.addTask {
                        do {
                            try await Task.sleep(for: allowedDuration)
                            return .processStillAlive
                        } catch {
                            // teardown(using:) cancells this task
                            // when process has exited
                            return .processHasExited
                        }
                    }
                    await self.gracefulShutDown(allowedDurationToNextStep: allowedDuration)
                    return await group.next()!
                }
            #if !os(Windows)
            case .sendSignal(let signal, let allowedDuration):
                stepCompletion = await withTaskGroup(of: TeardownStepCompletion.self) { group in
                    group.addTask {
                        do {
                            try await Task.sleep(for: allowedDuration)
                            return .processStillAlive
                        } catch {
                            // teardown(using:) cancells this task
                            // when process has exited
                            return .processHasExited
                        }
                    }
                    try? self.send(signal: signal)
                    return await group.next()!
                }
            #endif  // !os(Windows)
            case .kill:
                #if os(Windows)
                try? self.terminate(withExitCode: 0)
                #else
                try? self.send(signal: .kill)
                #endif
                stepCompletion = .killedTheProcess
            }

            switch stepCompletion {
            case .killedTheProcess, .processHasExited:
                return
            case .processStillAlive:
                // Continue to next step
                break
            }
        }
    }
}

func withUncancelledTask<Result: Sendable>(
    returning: Result.Type = Result.self,
    _ body: @Sendable @escaping () async -> Result
) async -> Result {
    // This looks unstructured but it isn't, please note that we `await` `.value` of this task.
    // The reason we need this separate `Task` is that in general, we cannot assume that code performs to our
    // expectations if the task we run it on is already cancelled. However, in some cases we need the code to
    // run regardless -- even if our task is already cancelled. Therefore, we create a new, uncancelled task here.
    await Task {
        await body()
    }.value
}
