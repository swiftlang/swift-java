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

import CSwiftJavaJNI
import SwiftJava

// FIXME: workaround until importing properly would make UCL inherit from CL https://github.com/swiftlang/swift-java/issues/423
extension URLClassLoader /* workaround for missing inherits from ClassLoader */ {
  @JavaMethod
  public func loadClass(_ name: String) throws -> JavaClass<JavaObject>?
}
