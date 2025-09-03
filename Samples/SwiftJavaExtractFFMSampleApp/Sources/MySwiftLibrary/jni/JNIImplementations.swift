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

import SwiftJava

@JavaClass("com.example.swift.HelloJava2Swift")
open class HelloJava2Swift: JavaObject {
}

extension JavaClass<HelloJava2Swift> {
}

/// Describes the Java `native` methods for ``HelloJava2Swift``.
///
/// To implement all of the `native` methods for HelloSwift in Swift,
/// extend HelloSwift to conform to this protocol and mark each
/// implementation of the protocol requirement with `@JavaMethod`.
protocol HelloJava2SwiftNativeMethods {
  func jniWriteString(_ message: String) -> Int32
  func jniGetInt() -> Int32
}

@JavaImplementation("com.example.swift.HelloJava2Swift")
extension HelloJava2Swift: HelloJava2SwiftNativeMethods {
  @JavaMethod
  func jniWriteString(_ message: String) -> Int32 {
    return Int32(message.count)
  }

  @JavaMethod
  func jniGetInt() -> Int32 {
    return 12
  }
}
