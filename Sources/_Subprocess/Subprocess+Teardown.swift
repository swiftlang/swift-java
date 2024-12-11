//
//  Suubprocess+Teardown.swift
//  SwiftExperimentalSubprocess
//
//  Created by Charles Hu on 12/6/24.
//

#if canImport(Darwin) || canImport(Glibc)

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

extension Subprocess {
    /// A step in the graceful shutdown teardown sequence.
    /// It consists of a signal to send to the child process and the
    /// number of nanoseconds allowed for the child process to exit
    /// before proceeding to the next step.
    public struct TeardownStep: Sendable, Hashable {
        internal enum Storage: Sendable, Hashable {
            case sendSignal(Signal, allowedNanoseconds: UInt64)
            case kill
        }
        var storage: Storage

        /// Sends `signal` to the process and provides `allowedNanoSecondsToExit`
        /// nanoseconds for the process to exit before proceeding to the next step.
        /// The final step in the sequence will always send a `.kill` signal.
        public static func sendSignal(
            _ signal: Signal,
            allowedNanoSecondsToExit: UInt64
        ) -> Self {
            return Self(
                storage: .sendSignal(
                    signal,
                    allowedNanoseconds: allowedNanoSecondsToExit
                )
            )
        }
    }
}

extension Subprocess {
    internal func runTeardownSequence(_ sequence: [TeardownStep]) async {
        // First insert the `.kill` step
        let finalSequence = sequence + [TeardownStep(storage: .kill)]
        for step in finalSequence {
            enum TeardownStepCompletion {
                case processHasExited
                case processStillAlive
                case killedTheProcess
            }
            let stepCompletion: TeardownStepCompletion

            guard self.isAlive() else {
                return
            }

            switch step.storage {
            case .sendSignal(let signal, let allowedNanoseconds):
                stepCompletion = await withTaskGroup(of: TeardownStepCompletion.self) { group in
                    group.addTask {
                        do {
                            try await Task.sleep(nanoseconds: allowedNanoseconds)
                            return .processStillAlive
                        } catch {
                            // teardown(using:) cancells this task
                            // when process has exited
                            return .processHasExited
                        }
                    }
                    try? self.send(signal, toProcessGroup: false)
                    return await group.next()!
                }
            case .kill:
                try? self.send(.kill, toProcessGroup: false)
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

extension Subprocess {
    private func isAlive() -> Bool {
        return kill(self.processIdentifier.value, 0) == 0
    }
}

func withUncancelledTask<R: Sendable>(
    returning: R.Type = R.self,
    _ body: @Sendable @escaping () async -> R
) async -> R {
    // This looks unstructured but it isn't, please note that we `await` `.value` of this task.
    // The reason we need this separate `Task` is that in general, we cannot assume that code performs to our
    // expectations if the task we run it on is already cancelled. However, in some cases we need the code to
    // run regardless -- even if our task is already cancelled. Therefore, we create a new, uncancelled task here.
    await Task {
        await body()
    }.value
}

#endif // canImport(Darwin) || canImport(Glibc)
