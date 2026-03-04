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

public protocol _RawDiscriminatorRepresentable {
  var _rawDiscriminator: Int32 { get }
}

@_cdecl("Java_org_swift_swiftkit_core_SwiftObjects_getRawDiscriminator__JJ")
public func Java_org_swift_swiftkit_core_SwiftObjects_getRawDiscriminator__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, selfTypePointer: jlong) -> jint {
  func perform<T: _RawDiscriminatorRepresentable>(as type: T.Type) -> jint {
    guard let self$ = UnsafeMutablePointer<T>(bitPattern: selfPointer) else {
      fatalError()
    }
    return self$.pointee._rawDiscriminator.getJNIValue(in: environment)
  }

  let selfTypeBits$ = Int(Int64(fromJNI: selfTypePointer, in: environment))
  guard let selfType$ = UnsafeRawPointer(bitPattern: selfTypeBits$) else {
    fatalError("selfType metadata address was null")
  }
  let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)
  guard let typeMetadata = typeMetadata as? (any _RawDiscriminatorRepresentable.Type) else {
    fatalError("_RawDiscriminatorRepresentable conformance did not found in \(typeMetadata)")
  }
  return perform(as: typeMetadata)
}

@_cdecl("Java_org_swift_swiftkit_core_SwiftObjects_toString__JJ")
public func Java_org_swift_swiftkit_core_SwiftObjects_toString__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, selfTypePointer: jlong) -> jstring? {
  func perform<T>(as type: T.Type) -> jstring? {
    guard let self$ = UnsafeMutablePointer<T>(bitPattern: selfPointer) else {
      fatalError()
    }
    return String(describing: self$.pointee).getJNIValue(in: environment)
  }

  let selfTypeBits$ = Int(Int64(fromJNI: selfTypePointer, in: environment))
  guard let selfType$ = UnsafeRawPointer(bitPattern: selfTypeBits$) else {
    fatalError("selfType metadata address was null")
  }
  let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)
  return perform(as: typeMetadata)
}

@_cdecl("Java_org_swift_swiftkit_core_SwiftObjects_toDebugString__JJ")
public func Java_org_swift_swiftkit_core_SwiftObjects_toDebugString__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, selfTypePointer: jlong) -> jstring? {
  func perform<T>(as type: T.Type) -> jstring? {
    guard let self$ = UnsafeMutablePointer<T>(bitPattern: selfPointer) else {
      fatalError()
    }
    return String(reflecting: self$.pointee).getJNIValue(in: environment)
  }

  let selfTypeBits$ = Int(Int64(fromJNI: selfTypePointer, in: environment))
  guard let selfType$ = UnsafeRawPointer(bitPattern: selfTypeBits$) else {
    fatalError("selfType metadata address was null")
  }
  let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)
  return perform(as: typeMetadata)
}

