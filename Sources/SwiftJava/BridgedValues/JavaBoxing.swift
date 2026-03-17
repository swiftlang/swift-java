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

import SwiftJavaJNICore

// ==== -----------------------------------------------------------------------
// MARK: JavaBoxable protocol

/// A type that can be boxed into and unboxed from a Java object via JNI.
/// This is used for dictionary keys and values that need to cross the JNI boundary
/// as boxed Java objects (e.g. Long, Double, Boolean, String).
public protocol JavaBoxable: JavaValue {
  /// Convert this Swift value to a boxed Java object.
  func toJavaObject(in environment: JNIEnvironment) -> jobject?

  /// Create a Swift value from a boxed Java object.
  static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Self
}

// ==== -----------------------------------------------------------------------
// MARK: JavaBoxable conformances

extension String: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    self.getJNIValue(in: environment)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> String {
    String(fromJNI: obj, in: environment)
  }
}

extension Int64: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Long")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(J)V")
    var args = [jvalue()]
    args[0].j = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Int64 {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "longValue", "()J")
    let result = environment.interface.CallLongMethodA(environment, obj, methodID, nil)
    return Int64(fromJNI: result, in: environment)
  }
}

extension Int32: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Integer")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(I)V")
    var args = [jvalue()]
    args[0].i = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Int32 {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "intValue", "()I")
    let result = environment.interface.CallIntMethodA(environment, obj, methodID, nil)
    return Int32(fromJNI: result, in: environment)
  }
}

extension Double: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Double")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(D)V")
    var args = [jvalue()]
    args[0].d = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Double {
    guard let obj else { return 0.0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "doubleValue", "()D")
    let result = environment.interface.CallDoubleMethodA(environment, obj, methodID, nil)
    return Double(fromJNI: result, in: environment)
  }
}

extension Float: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Float")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(F)V")
    var args = [jvalue()]
    args[0].f = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Float {
    guard let obj else { return 0.0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "floatValue", "()F")
    let result = environment.interface.CallFloatMethodA(environment, obj, methodID, nil)
    return Float(fromJNI: result, in: environment)
  }
}

extension Bool: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Boolean")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(Z)V")
    var args = [jvalue()]
    args[0].z = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Bool {
    guard let obj else { return false }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "booleanValue", "()Z")
    let result = environment.interface.CallBooleanMethodA(environment, obj, methodID, nil)
    return Bool(fromJNI: result, in: environment)
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Byte-sized integer types (Int8/UInt8 -> java.lang.Byte)

extension Int8: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Byte")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(B)V")
    var args = [jvalue()]
    args[0].b = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Int8 {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "byteValue", "()B")
    let result = environment.interface.CallByteMethodA(environment, obj, methodID, nil)
    return Int8(fromJNI: result, in: environment)
  }
}

extension UInt8: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Byte")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(B)V")
    var args = [jvalue()]
    args[0].b = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> UInt8 {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "byteValue", "()B")
    let result = environment.interface.CallByteMethodA(environment, obj, methodID, nil)
    return UInt8(fromJNI: result, in: environment)
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Short-sized integer types (Int16 -> java.lang.Short)

extension Int16: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Short")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(S)V")
    var args = [jvalue()]
    args[0].s = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Int16 {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "shortValue", "()S")
    let result = environment.interface.CallShortMethodA(environment, obj, methodID, nil)
    return Int16(fromJNI: result, in: environment)
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Unsigned 32/64-bit types

extension UInt32: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Integer")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(I)V")
    var args = [jvalue()]
    args[0].i = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> UInt32 {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "intValue", "()I")
    let result = environment.interface.CallIntMethodA(environment, obj, methodID, nil)
    return UInt32(fromJNI: result, in: environment)
  }
}

extension UInt64: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Long")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(J)V")
    var args = [jvalue()]
    args[0].j = self.getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> UInt64 {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "longValue", "()J")
    let result = environment.interface.CallLongMethodA(environment, obj, methodID, nil)
    return UInt64(fromJNI: result, in: environment)
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Platform-width integer types (Int/UInt -> java.lang.Long)

extension Int: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Long")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(J)V")
    var args = [jvalue()]
    args[0].j = Int64(self).getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Int {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "longValue", "()J")
    let result = environment.interface.CallLongMethodA(environment, obj, methodID, nil)
    return Int(Int64(fromJNI: result, in: environment))
  }
}

extension UInt: JavaBoxable {
  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let cls = environment.interface.FindClass(environment, "java/lang/Long")
    let methodID = environment.interface.GetMethodID(environment, cls, "<init>", "(J)V")
    var args = [jvalue()]
    args[0].j = Int64(bitPattern: UInt64(self)).getJNIValue(in: environment)
    return environment.interface.NewObjectA(environment, cls, methodID, &args)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> UInt {
    guard let obj else { return 0 }
    let cls = environment.interface.GetObjectClass(environment, obj)
    let methodID = environment.interface.GetMethodID(environment, cls, "longValue", "()J")
    let result = environment.interface.CallLongMethodA(environment, obj, methodID, nil)
    return UInt(UInt64(fromJNI: result, in: environment))
  }
}


// ==== -----------------------------------------------------------------------
// MARK: SwiftDictionaryBox (type-erased base + generic subclass)

/// Non-generic base class for dictionary boxes, allowing dispatch
/// from @_cdecl JNI functions without knowing the concrete key/value types.
///
/// Note: This must be a class (not a protocol) because instances are stored
/// via `Unmanaged` in a raw pointer passed across the JNI boundary.
class AnySwiftDictionaryBox {
  func size() -> Int { fatalError("abstract") }
  func get(key: jobject?, environment: JNIEnvironment) -> jobject? { fatalError("abstract") }
  func containsKey(key: jobject?, environment: JNIEnvironment) -> Bool { fatalError("abstract") }
  func keys(environment: JNIEnvironment) -> jobject? { fatalError("abstract") }
  func values(environment: JNIEnvironment) -> jobject? { fatalError("abstract") }
  func dictionaryAsAny() -> Any { fatalError("abstract") }
}

/// Generic subclass that wraps a concrete `[K: V]` Swift dictionary.
final class SwiftDictionaryBox<K: JavaBoxable & Hashable, V: JavaBoxable>: AnySwiftDictionaryBox {
  let dictionary: [K: V]

  init(_ dictionary: [K: V]) {
    self.dictionary = dictionary
  }

  override func size() -> Int {
    dictionary.count
  }

  override func dictionaryAsAny() -> Any {
    dictionary
  }

  override func get(key: jobject?, environment: JNIEnvironment) -> jobject? {
    let swiftKey = K.fromJavaObject(key, in: environment)
    guard let value = dictionary[swiftKey] else { return nil }
    return value.toJavaObject(in: environment)
  }

  override func containsKey(key: jobject?, environment: JNIEnvironment) -> Bool {
    let swiftKey = K.fromJavaObject(key, in: environment)
    return dictionary[swiftKey] != nil
  }

  override func keys(environment: JNIEnvironment) -> jobject? {
    let keysArray = Array(dictionary.keys)
    let objectClass = environment.interface.FindClass(environment, "java/lang/Object")
    let result = environment.interface.NewObjectArray(environment, jsize(keysArray.count), objectClass, nil)
    for (i, key) in keysArray.enumerated() {
      let javaKey = key.toJavaObject(in: environment)
      environment.interface.SetObjectArrayElement(environment, result, jsize(i), javaKey)
    }
    return result
  }

  override func values(environment: JNIEnvironment) -> jobject? {
    let valuesArray = Array(dictionary.values)
    let objectClass = environment.interface.FindClass(environment, "java/lang/Object")
    let result = environment.interface.NewObjectArray(environment, jsize(valuesArray.count), objectClass, nil)
    for (i, value) in valuesArray.enumerated() {
      let javaValue = value.toJavaObject(in: environment)
      environment.interface.SetObjectArrayElement(environment, result, jsize(i), javaValue)
    }
    return result
  }
}

// ==== -----------------------------------------------------------------------
// MARK: SwiftSetBox (type-erased base + generic subclass)

/// Non-generic base class for set boxes, allowing dispatch
/// from @_cdecl JNI functions without knowing the concrete element type.
///
/// Note: This must be a class (not a protocol) because instances are stored
/// via `Unmanaged` in a raw pointer passed across the JNI boundary.
class AnySwiftSetBox {
  func size() -> Int { fatalError("abstract") }
  func contains(element: jobject?, environment: JNIEnvironment) -> Bool { fatalError("abstract") }
  func toArray(environment: JNIEnvironment) -> jobject? { fatalError("abstract") }
  func setAsAny() -> Any { fatalError("abstract") }
}

/// Generic subclass that wraps a concrete `Set<E>` Swift set.
final class SwiftSetBox<E: JavaBoxable & Hashable>: AnySwiftSetBox {
  let set: Set<E>

  init(_ set: Set<E>) {
    self.set = set
  }

  override func size() -> Int {
    set.count
  }

  override func setAsAny() -> Any {
    set
  }

  override func contains(element: jobject?, environment: JNIEnvironment) -> Bool {
    let swiftElement = E.fromJavaObject(element, in: environment)
    return set.contains(swiftElement)
  }

  override func toArray(environment: JNIEnvironment) -> jobject? {
    let elements = Array(set)
    let objectClass = environment.interface.FindClass(environment, "java/lang/Object")
    let result = environment.interface.NewObjectArray(environment, jsize(elements.count), objectClass, nil)
    for (i, element) in elements.enumerated() {
      let javaElement = element.toJavaObject(in: environment)
      environment.interface.SetObjectArrayElement(environment, result, jsize(i), javaElement)
    }
    return result
  }
}
