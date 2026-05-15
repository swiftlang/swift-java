//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJava

public protocol JextractedTypeBridge: JobjectBridge {
  static var javaClass: jclass { get }
  static var wrapMemoryAddressUnsafe: jmethodID { get }
}

extension JextractedTypeBridge {
  public static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
    let selfPointer$ = UnsafeMutablePointer<SwiftType>.allocate(capacity: 1)
    selfPointer$.initialize(to: value)
    let selfPointerBits$ = Int64(Int(bitPattern: selfPointer$))
    var args = [jvalue(), jvalue()]
    args[0].j = selfPointerBits$.getJNIValue(in: environment)
    args[1].l = JavaSwiftArena.defaultAutoArena.javaThis
    return environment.interface.CallStaticObjectMethodA(
      environment,
      Self.javaClass,
      Self.wrapMemoryAddressUnsafe,
      &args
    )
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType {
    guard let obj else {
      fatalError("fromJavaObject received a null Java object")
    }
    let selfPointer$ = environment.interface.CallLongMethodA(
      environment,
      obj,
      _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
      nil
    )
    let selfPointerBits$ = Int(Int64(fromJNI: selfPointer$, in: environment))
    guard let valuePointer$ = UnsafeMutablePointer<SwiftType>(bitPattern: selfPointerBits$) else {
      fatalError("fromJavaObject received a null Swift memory address")
    }
    return valuePointer$.pointee
  }

  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    try body(javaClass)
  }
}

public protocol JextractedGenericTypeBridge: JextractedTypeBridge {}

extension JextractedGenericTypeBridge {
  public static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
    let selfPointer$ = UnsafeMutablePointer<SwiftType>.allocate(capacity: 1)
    selfPointer$.initialize(to: value)
    let selfPointerBits$ = Int64(Int(bitPattern: selfPointer$))
    let selfTypePointer$ = unsafeBitCast(SwiftType.self, to: UnsafeRawPointer.self)
    let selfTypePointerBits$ = Int64(Int(bitPattern: selfTypePointer$))
    var args = [jvalue(), jvalue(), jvalue()]
    args[0].j = selfPointerBits$.getJNIValue(in: environment)
    args[1].j = selfTypePointerBits$.getJNIValue(in: environment)
    args[2].l = JavaSwiftArena.defaultAutoArena.javaThis
    return environment.interface.CallStaticObjectMethodA(
      environment,
      Self.javaClass,
      Self.wrapMemoryAddressUnsafe,
      &args
    )
  }
}
