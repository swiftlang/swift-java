//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public struct Box<Element> {
  public var count: Int64

  public init(count: Int64) {
    self.count = count
  }
}

public struct Fish {
  public var name: String

  public init(name: String) {
    self.name = name
  }
}

extension Box where Element == Fish {
  public func describeFish() -> String {
    "A box of \(count) fish"
  }
}

public typealias FishBox = Box<Fish>
