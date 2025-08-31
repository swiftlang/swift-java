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


extension AnyJavaObject {
  /// Look up the other class type
  ///
  /// - Returns: `nil` when either `OtherClass` isn't known to the
  ///   Java environment or this object isn't an instance of that type.
  private func isInstanceOf<OtherClass: AnyJavaObject>(
    _ otherClass: OtherClass.Type
  ) -> jclass? {
    try? otherClass.withJNIClass(in: javaEnvironment) { otherJavaClass in
      if javaEnvironment.interface.IsInstanceOf(
       javaEnvironment,
       javaThis,
       otherJavaClass
     ) == 0 {
       return nil
     }

     return otherJavaClass
    }
  }

  /// Determine whether this object is an instance of a specific
  /// Java class.
  public func `is`<OtherClass: AnyJavaObject>(_ otherClass: OtherClass.Type) -> Bool {
    return isInstanceOf(otherClass) != nil
  }

  /// Attempt to downcast this object to a specific Java class.
  public func `as`<OtherClass: AnyJavaObject>(_ otherClass: OtherClass.Type) -> OtherClass? {
    if `is`(otherClass) {
      return OtherClass(javaHolder: javaHolder)
    }

    return nil
  }
}
