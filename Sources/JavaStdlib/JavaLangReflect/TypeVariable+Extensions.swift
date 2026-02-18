//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
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

// FIXME: all interfaces should ahve these https://github.com/swiftlang/swift-java/issues/430
extension TypeVariable {

  @JavaMethod
  public func toString() -> String

  @JavaMethod
  public func getClass() -> JavaClass<JavaObject>!

  @JavaMethod
  public func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func hashCode() -> Int32

}

// FIXME: All Java objects are Hashable, we should handle that accordingly.
extension TypeVariable: Hashable {

  public func hash(into hasher: inout Hasher) {
    guard let pojo = self.as(JavaObject.self) else {
      return
    }

    hasher.combine(pojo.hashCode())
  }

  public static func == (lhs: TypeVariable<D>, rhs: TypeVariable<D>) -> Bool {
    guard let lhpojo: JavaObject = lhs.as(JavaObject.self) else {
      return false
    }
    guard let rhpojo: JavaObject = rhs.as(JavaObject.self) else {
      return false
    }

    return lhpojo.equals(rhpojo)
  }

}

extension TypeVariable {
  public var description: String {
    toString()
  }
}
