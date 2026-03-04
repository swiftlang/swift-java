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
  guard let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self) as? (any _RawDiscriminatorRepresentable.Type) else {
    return 0
  }
  return perform(as: typeMetadata)
}
