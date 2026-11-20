//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Synchronization

public final class AsyncCancellationProbe: Sendable {
  private struct State {
    var cancelled = false
    var waitingToReturn: CheckedContinuation<Void, Never>?
    var destroyedResults: Int32 = 0
  }

  private let state = Mutex(State())

  public init() {}

  public func waitForCancellation() async throws -> Int64 {
    do {
      try await Task.sleep(for: .seconds(60))
      return 1
    } catch {
      state.withLock { $0.cancelled = Task.isCancelled }
      throw error
    }
  }

  public func waitForOptionalCancellation() async throws -> Int64? {
    try await waitForCancellation()
  }

  public func makeOwnedResult() async -> AsyncOwnedResult {
    newOwnedResult()
  }

  public func makeOwnedResults() async -> [AsyncOwnedResult] {
    [newOwnedResult(), newOwnedResult()]
  }

  public func makeOwnedTuple() async -> (AsyncOwnedResult, [String: AsyncOwnedResult], Set<Int32>) {
    (newOwnedResult(), ["value": newOwnedResult()], [42])
  }

  private func newOwnedResult() -> AsyncOwnedResult {
    AsyncOwnedResult { [self] in state.withLock { $0.destroyedResults += 1 } }
  }

  public func returnOwnedResultWhenAllowed() async -> AsyncOwnedResult {
    await withCheckedContinuation { continuation in
      state.withLock { $0.waitingToReturn = continuation }
    }
    return newOwnedResult()
  }

  public func returnOwnedResultAfterCancellation() async -> AsyncOwnedResult {
    _ = try? await waitForCancellation()
    return newOwnedResult()
  }

  public func returnOwnedResultsAfterCancellation() async -> [AsyncOwnedResult] {
    _ = try? await waitForCancellation()
    return [newOwnedResult(), newOwnedResult()]
  }

  public func wasCancelled() -> Bool { state.withLock { $0.cancelled } }

  public func isWaitingToReturn() -> Bool { state.withLock { $0.waitingToReturn != nil } }

  public func allowReturn() {
    let continuation = state.withLock {
      let continuation = $0.waitingToReturn
      $0.waitingToReturn = nil
      return continuation
    }
    continuation?.resume()
  }

  public func destroyedResults() -> Int32 { state.withLock { $0.destroyedResults } }
}

public final class AsyncOwnedResult: Sendable {
  private let onDestroy: @Sendable () -> Void

  fileprivate init(onDestroy: @escaping @Sendable () -> Void) {
    self.onDestroy = onDestroy
  }

  deinit {
    onDestroy()
  }
}
