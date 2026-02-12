//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public class CallbackManager {
  private var callback: (() -> Void)?
  private var intCallback: ((Int64) -> Int64)?

  public init() {}

  public func setCallback(callback: @escaping () -> Void) {
    self.callback = callback
  }

  public func triggerCallback() {
    callback?()
  }

  public func clearCallback() {
    callback = nil
  }

  public func setIntCallback(callback: @escaping (Int64) -> Int64) {
    self.intCallback = callback
  }

  public func triggerIntCallback(value: Int64) -> Int64? {
    intCallback?(value)
  }
}

public class ClosureStore {
  private var closures: [() -> Void] = []

  public init() {}

  public func addClosure(closure: @escaping () -> Void) {
    closures.append(closure)
  }

  public func executeAll() {
    for closure in closures {
      closure()
    }
  }

  public func clear() {
    closures.removeAll()
  }

  public func count() -> Int64 {
    Int64(closures.count)
  }
}

public func multipleEscapingClosures(
  onSuccess: @escaping (Int64) -> Void,
  onFailure: @escaping (Int64) -> Void,
  condition: Bool
) {
  if condition {
    onSuccess(42)
  } else {
    onFailure(-1)
  }
}
