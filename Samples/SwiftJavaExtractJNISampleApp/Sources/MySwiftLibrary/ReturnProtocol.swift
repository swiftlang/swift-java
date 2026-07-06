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

public protocol Greeter {
  func greeting() -> String
  func repeated(count: Int64) -> String
}

public struct EnglishGreeter: Greeter {
  public let name: String

  public init(name: String) {
    self.name = name
  }

  public func greeting() -> String {
    "Hello, \(name)!"
  }

  public func repeated(count: Int64) -> String {
    Array(repeating: greeting(), count: Int(count)).joined(separator: " ")
  }
}

public struct DanishGreeter: Greeter {
  public let name: String

  public init(name: String) {
    self.name = name
  }

  public func greeting() -> String {
    "Hej, \(name)!"
  }

  public func repeated(count: Int64) -> String {
    Array(repeating: greeting(), count: Int(count)).joined(separator: " ")
  }
}

public func makeEnglishGreeter(name: String) -> any Greeter {
  EnglishGreeter(name: name)
}

public func makeDanishGreeter(name: String) -> any Greeter {
  DanishGreeter(name: name)
}

public func makeOpaqueGreeter(name: String) -> some Greeter {
  EnglishGreeter(name: name)
}

public func describeGreeter(_ greeter: any Greeter) -> String {
  greeter.greeting()
}
