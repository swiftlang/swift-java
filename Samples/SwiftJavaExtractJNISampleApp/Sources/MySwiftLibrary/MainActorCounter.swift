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

// Compiling the generated thunks exercises main actor isolation checking.
@MainActor
public final class MainActorCounter {
  public var value: Int64

  public init(value: Int64) {
    self.value = value
  }

  public func increment() {
    value += 1
  }

  public func label() -> String {
    "Count: \(value)"
  }

  public func checkedValue() throws -> Int64 {
    value
  }

  public nonisolated func constant() -> Int64 {
    42
  }

  public nonisolated var constantValue: Int64 { 42 }

  public subscript(offset: Int64) -> Int64 {
    get { value + offset }
    set { value = newValue - offset }
  }

  public static func initialValue() -> Int64 {
    0
  }
}

extension MainActorCounter {
  public func reset() {
    value = 0
  }
}

@_Concurrency.MainActor
public func mainActorAnswer() -> Int64 {
  42
}

@MainActor
public func mainActorThrowingAnswer() throws -> Int64 {
  42
}
