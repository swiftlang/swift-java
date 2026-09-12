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

  /// A container for receiving Swift generic instances.
  static var _OutSwiftGenericInstance: JavaType {
    .class(package: "org.swift.swiftkit.core", name: "_OutSwiftGenericInstance")
  }

  static var SwiftObserverCallback: JavaType {
    .class(package: "org.swift.swiftkit.observable", name: "SwiftObserverCallback")
  }
}
