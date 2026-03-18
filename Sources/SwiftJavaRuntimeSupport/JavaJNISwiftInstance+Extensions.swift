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

extension JavaJNISwiftInstance {
  @JavaMethod("$memoryAddress")
  public func memoryAddress() -> Int64
}

extension JavaJNISwiftInstance: AnyJavaObjectWithCustomClassLoader {
  public static func getJavaClassLoader(in environment: JNIEnvironment) throws -> JavaClassLoader! {
    // OK to force unwrap, we are in a jextract environment.
    JNI.shared!.applicationClassLoader
  }
}
