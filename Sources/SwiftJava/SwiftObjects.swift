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

@JavaClass("org.swift.swiftkit.core.SwiftObjects")
open class SwiftObjects: JavaObject {
}

@JavaImplementation("org.swift.swiftkit.core.SwiftObjects")
extension SwiftObjects {
  @JavaMethod
  public static func getRawDiscriminator(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64, selfTypePointer: Int64) -> Int32 {
    guard let selfType$ = UnsafeRawPointer(bitPattern: Int(selfTypePointer)) else {
      fatalError("selfType metadata address was null")
    }
    let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)
    guard let typeMetadata = typeMetadata as? (any _RawDiscriminatorRepresentable.Type) else {
      fatalError("_RawDiscriminatorRepresentable conformance did not found in \(typeMetadata)")
    }

    func perform<T: _RawDiscriminatorRepresentable>(as type: T.Type) -> Int32 {
      guard let self$ = UnsafeMutablePointer<T>(bitPattern: Int(selfPointer)) else {
        fatalError("self memory address was null")
      }
      return self$.pointee._rawDiscriminator
    }
    return perform(as: typeMetadata)
  }

  @JavaMethod
  public static func toString(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64, selfTypePointer: Int64) -> String {
    guard let selfType$ = UnsafeRawPointer(bitPattern: Int(selfTypePointer)) else {
      fatalError("selfType metadata address was null")
    }
    let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)

    func perform<T>(as type: T.Type) -> String {
      guard let self$ = UnsafeMutablePointer<T>(bitPattern: Int(selfPointer)) else {
        fatalError("self memory address was null")
      }
      return String(describing: self$.pointee)
    }
    return perform(as: typeMetadata)
  }

  @JavaMethod
  public static func toDebugString(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64, selfTypePointer: Int64) -> String {
    guard let selfType$ = UnsafeRawPointer(bitPattern: Int(selfTypePointer)) else {
      fatalError("selfType metadata address was null")
    }
    let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)

    func perform<T>(as type: T.Type) -> String {
      guard let self$ = UnsafeMutablePointer<T>(bitPattern: Int(selfPointer)) else {
        fatalError("self memory address was null")
      }
      return String(reflecting: self$.pointee)
    }
    return perform(as: typeMetadata)
  }

  @JavaMethod
  public static func destroy(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64, selfTypePointer: Int64) {
    guard let selfType$ = UnsafeRawPointer(bitPattern: Int(selfTypePointer)) else {
      fatalError("selfType metadata address was null")
    }
    let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)

    func perform<T>(as type: T.Type) {
      guard let self$ = UnsafeMutablePointer<T>(bitPattern: Int(selfPointer)) else {
        fatalError("self memory address was null")
      }
      self$.deinitialize(count: 1)
      self$.deallocate()
    }
    return perform(as: typeMetadata)
  }
}
