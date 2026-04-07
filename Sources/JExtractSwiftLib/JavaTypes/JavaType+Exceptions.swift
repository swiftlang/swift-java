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

import SwiftJavaJNICore

extension JavaType {

  /// The Java exception type for the Swift error wrapper
  static var swiftJavaErrorException: JavaType {
    .class(package: "org.swift.swiftkit.ffm.generated", name: "SwiftJavaErrorException")
  }

  /// The Java exception type for integer overflow checks
  static var swiftIntegerOverflowException: JavaType {
    .class(package: "org.swift.swiftkit.core", name: "SwiftIntegerOverflowException")
  }

}
