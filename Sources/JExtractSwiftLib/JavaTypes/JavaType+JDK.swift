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

import SwiftJNI

extension JavaType {
  /// The description of the type java.lang.foreign.MemorySegment.
  static var javaForeignMemorySegment: JavaType {
    .class(package: "java.lang.foreign", name: "MemorySegment")
  }

  /// The description of the type java.lang.String.
  static var javaLangString: JavaType {
    .class(package: "java.lang", name: "String")
  }

  /// The description of the type java.lang.Runnable.
  static var javaLangRunnable: JavaType {
    .class(package: "java.lang", name: "Runnable")
  }

  /// The description of the type java.lang.Class.
  static var javaLangClass: JavaType {
    .class(package: "java.lang", name: "Class")
  }

  /// The description of the type java.lang.Throwable.
  static var javaLangThrowable: JavaType {
    .class(package: "java.lang", name: "Throwable")
  }
}
