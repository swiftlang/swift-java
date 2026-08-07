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

public struct GreeterError: Error {}

public protocol RichGreeter {
  func nickname() -> String?
  func aliases() -> [String]
  func decorate(_ object: MySwiftClass) -> MySwiftClass
  func greetOrThrow(shouldThrow: Bool) throws -> String
  func recordGreeting()
  func count() -> Int64
}

public final class RichGreeterImpl: RichGreeter {
  private var greetings: Int64 = 0
  private let base: String

  public init(base: String) {
    self.base = base
  }

  public func nickname() -> String? {
    base.isEmpty ? nil : "Mr. \(base)"
  }

  public func aliases() -> [String] {
    [base, base + base]
  }

  public func decorate(_ object: MySwiftClass) -> MySwiftClass {
    MySwiftClass(x: object.x + 1, y: object.y + 1)
  }

  public func greetOrThrow(shouldThrow: Bool) throws -> String {
    if shouldThrow {
      throw GreeterError()
    }
    return "Hi \(base)"
  }

  public func recordGreeting() {
    greetings += 1
  }

  public func count() -> Int64 {
    greetings
  }
}

public func makeRichGreeter(base: String) -> any RichGreeter {
  RichGreeterImpl(base: base)
}
