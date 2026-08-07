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

  @JavaMethod
  public static func typeDescription(environment: UnsafeMutablePointer<JNIEnv?>!, selfTypePointer: Int64) -> String {
    guard let selfType$ = UnsafeRawPointer(bitPattern: Int(selfTypePointer)) else {
      fatalError("selfType metadata address was null")
    }
    let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)
    return String(describing: typeMetadata)
  }

  @JavaMethod
  public static func equals(environment: UnsafeMutablePointer<JNIEnv?>!, lhsPointer: Int64, lhsTypePointer: Int64, rhsPointer: Int64, rhsTypePointer: Int64) -> Bool {
    // Fallback for non-equatable types (such as classes)
    let isPointerIdentityEqual = lhsTypePointer == rhsTypePointer && lhsPointer == rhsPointer

    guard let lhsType$ = UnsafeRawPointer(bitPattern: Int(lhsTypePointer)) else {
      fatalError("lhsType metadata address was null")
    }
    let lhsMetatype = unsafeBitCast(lhsType$, to: Any.Type.self)
    guard let lhsMetatype = lhsMetatype as? (any Equatable.Type) else {
      return isPointerIdentityEqual
    }

    guard let rhsType$ = UnsafeRawPointer(bitPattern: Int(rhsTypePointer)) else {
      fatalError("rhsType metadata address was null")
    }
    let rhsMetatype = unsafeBitCast(rhsType$, to: Any.Type.self)
    guard let rhsMetatype = rhsMetatype as? (any Equatable.Type) else {
      return isPointerIdentityEqual
    }

    func perform<L: Equatable, R: Equatable>(lhsType: L.Type, rhsType: R.Type) -> Bool {
      guard let lhs$ = UnsafeMutablePointer<L>(bitPattern: Int(lhsPointer)) else {
        fatalError("lhs memory address was null")
      }
      guard let rhs$ = UnsafeMutablePointer<R>(bitPattern: Int(rhsPointer)) else {
        fatalError("rhs memory address was null")
      }
      if lhsType == rhsType {
        return lhs$.pointee == rhs$.pointee as! L
      } else if let lhs = lhs$.pointee as? R {
        return lhs == rhs$.pointee
      } else if let rhs = rhs$.pointee as? L {
        return lhs$.pointee == rhs
      }
      return false
    }
    return perform(lhsType: lhsMetatype, rhsType: rhsMetatype)
  }

  @JavaMethod
  public static func hashCode(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64, selfTypePointer: Int64) -> Int32 {
    guard let selfType$ = UnsafeRawPointer(bitPattern: Int(selfTypePointer)) else {
      fatalError("selfType metadata address was null")
    }
    let typeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)
    guard let typeMetadata = typeMetadata as? (any Hashable.Type) else {
      // For value types, different instances may return different hash codes even if the values are same.
      return Int32(truncatingIfNeeded: selfPointer.hashValue)
    }

    func perform<T: Hashable>(as type: T.Type) -> Int32 {
      guard let self$ = UnsafeMutablePointer<T>(bitPattern: Int(selfPointer)) else {
        fatalError("self memory address was null")
      }
      return Int32(truncatingIfNeeded: self$.pointee.hashValue)
    }
    return perform(as: typeMetadata)
  }

  @JavaMethod
  public static func dynamicCast(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    selfPointer: Int64,
    selfTypePointer: Int64,
    targetTypePointter: Int64
  ) -> Int64 {
    guard let selfType$ = UnsafeRawPointer(bitPattern: Int(selfTypePointer)) else {
      fatalError("selfType metadata address was null")
    }
    guard let targetType$ = UnsafeRawPointer(bitPattern: Int(targetTypePointter)) else {
      fatalError("targetType metadata address was null")
    }

    let selfTypeMetadata = unsafeBitCast(selfType$, to: Any.Type.self)
    let targetTypeMetadata = unsafeBitCast(targetType$, to: Any.Type.self)

    func perform<S, T>(srcType: S.Type, targetType: T.Type) -> Int64 {
      guard let self$ = UnsafeMutablePointer<S>(bitPattern: Int(selfPointer)) else {
        fatalError("self memory address was null")
      }

      guard let castedValue = self$.pointee as? T else { return 0 }
      let castedPointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
      castedPointer.initialize(to: castedValue)
      return Int64(Int(bitPattern: castedPointer))
    }
    return perform(srcType: selfTypeMetadata, targetType: targetTypeMetadata)
  }
}

public class HashableClass: Hashable {
  public let value: Int
  public init(value: Int) {
    self.value = value
  }

  public static func == (lhs: HashableClass, rhs: HashableClass) -> Bool {
    lhs.value == rhs.value
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }
}
