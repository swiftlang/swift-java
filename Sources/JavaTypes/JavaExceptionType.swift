//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Describes a Java exception class (e.g. `SwiftIntegerOverflowException`)
public struct JavaExceptionType: Equatable, Hashable {
  public let type: JavaType
  public let message: String?

  public init(className name: some StringProtocol, message: String? = nil) {
    self.type = JavaType(className: name)
    self.message = message
  }
}

extension JavaExceptionType {
  public static var integerOverflow: JavaExceptionType {
    JavaExceptionType(className: "org.swift.swiftkit.core.SwiftIntegerOverflowException")
  }
}
