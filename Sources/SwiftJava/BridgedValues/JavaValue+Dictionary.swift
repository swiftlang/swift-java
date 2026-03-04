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
import JavaTypes

// MARK: - JavaBoxable protocol

/// A type that can be boxed into and unboxed from a Java object via JNI.
/// This is used for dictionary keys and values that need to cross the JNI boundary
/// as boxed Java objects (e.g. Long, Double, Boolean, String).
public protocol JavaBoxable: JavaValue {
  /// Convert this Swift value to a boxed Java object.
  func toJavaObject(in environment: JNIEnvironment) -> jobject?

  /// Create a Swift value from a boxed Java object.
  static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Self
}

// MARK: - JavaBoxable conformances

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

// MARK: - SwiftDictionaryBox (type-erased base + generic subclass)

/// Non-generic base class for dictionary boxes, allowing virtual dispatch
/// from @_cdecl JNI functions without knowing the concrete key/value types.
public class SwiftDictionaryBoxBase {
  public func size() -> Int { fatalError("abstract") }
  public func get(key: jobject?, environment: JNIEnvironment) -> jobject? { fatalError("abstract") }
  public func containsKey(key: jobject?, environment: JNIEnvironment) -> Bool { fatalError("abstract") }
  public func keys(environment: JNIEnvironment) -> jobject? { fatalError("abstract") }
  public func values(environment: JNIEnvironment) -> jobject? { fatalError("abstract") }
}

/// Generic subclass that wraps a concrete `[K: V]` Swift dictionary.
public final class SwiftDictionaryBox<K: JavaBoxable & Hashable, V: JavaBoxable>: SwiftDictionaryBoxBase {
  public let dictionary: [K: V]

  public init(_ dictionary: [K: V]) {
    self.dictionary = dictionary
  }

  public override func size() -> Int {
    dictionary.count
  }

  public override func get(key: jobject?, environment: JNIEnvironment) -> jobject? {
    let swiftKey = K.fromJavaObject(key, in: environment)
    guard let value = dictionary[swiftKey] else { return nil }
    return value.toJavaObject(in: environment)
  }

  public override func containsKey(key: jobject?, environment: JNIEnvironment) -> Bool {
    let swiftKey = K.fromJavaObject(key, in: environment)
    return dictionary[swiftKey] != nil
  }

  public override func keys(environment: JNIEnvironment) -> jobject? {
    let keysArray = Array(dictionary.keys)
    let objectClass = environment.interface.FindClass(environment, "java/lang/Object")
    let result = environment.interface.NewObjectArray(environment, jsize(keysArray.count), objectClass, nil)
    for (i, key) in keysArray.enumerated() {
      let javaKey = key.toJavaObject(in: environment)
      environment.interface.SetObjectArrayElement(environment, result, jsize(i), javaKey)
    }
    return result
  }

  public override func values(environment: JNIEnvironment) -> jobject? {
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

// MARK: - Dictionary extension for JNI bridging

extension Dictionary where Key: JavaBoxable & Hashable, Value: JavaBoxable {
  /// Box this dictionary and return a jlong pointer for passing across JNI.
  /// The dictionary is retained on the Swift heap; Java holds the pointer.
  public func dictionaryGetJNIValue(in environment: JNIEnvironment) -> jlong {
    let box = SwiftDictionaryBox<Key, Value>(self)
    let unmanaged = Unmanaged.passRetained(box)
    let rawPointer = unmanaged.toOpaque()
    return jlong(Int(bitPattern: rawPointer))
  }

  /// Reconstruct a Swift dictionary from a JNI jlong pointer to a SwiftDictionaryBox.
  public init(fromJNI value: jlong, in environment: JNIEnvironment) {
    let rawPointer = UnsafeRawPointer(bitPattern: Int(value))!
    let box = Unmanaged<SwiftDictionaryBox<Key, Value>>.fromOpaque(rawPointer).takeUnretainedValue()
    self = box.dictionary
  }
}

// MARK: - @_cdecl JNI native method implementations

@_cdecl("Java_org_swift_swiftkit_core_NativeSwiftDictionaryMap__00024size")
public func Java_NativeSwiftDictionaryMap_size(
  environment: UnsafeMutablePointer<JNIEnv?>!,
  thisClass: jclass,
  pointer: jlong
) -> jint {
  let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
  let box = Unmanaged<SwiftDictionaryBoxBase>.fromOpaque(rawPointer).takeUnretainedValue()
  return jint(box.size())
}

@_cdecl("Java_org_swift_swiftkit_core_NativeSwiftDictionaryMap__00024get")
public func Java_NativeSwiftDictionaryMap_get(
  environment: UnsafeMutablePointer<JNIEnv?>!,
  thisClass: jclass,
  pointer: jlong,
  key: jobject?
) -> jobject? {
  let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
  let box = Unmanaged<SwiftDictionaryBoxBase>.fromOpaque(rawPointer).takeUnretainedValue()
  return box.get(key: key, environment: environment)
}

@_cdecl("Java_org_swift_swiftkit_core_NativeSwiftDictionaryMap__00024containsKey")
public func Java_NativeSwiftDictionaryMap_containsKey(
  environment: UnsafeMutablePointer<JNIEnv?>!,
  thisClass: jclass,
  pointer: jlong,
  key: jobject?
) -> jboolean {
  let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
  let box = Unmanaged<SwiftDictionaryBoxBase>.fromOpaque(rawPointer).takeUnretainedValue()
  return box.containsKey(key: key, environment: environment) ? jboolean(JNI_TRUE) : jboolean(JNI_FALSE)
}

@_cdecl("Java_org_swift_swiftkit_core_NativeSwiftDictionaryMap__00024keys")
public func Java_NativeSwiftDictionaryMap_keys(
  environment: UnsafeMutablePointer<JNIEnv?>!,
  thisClass: jclass,
  pointer: jlong
) -> jobject? {
  let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
  let box = Unmanaged<SwiftDictionaryBoxBase>.fromOpaque(rawPointer).takeUnretainedValue()
  return box.keys(environment: environment)
}

@_cdecl("Java_org_swift_swiftkit_core_NativeSwiftDictionaryMap__00024values")
public func Java_NativeSwiftDictionaryMap_values(
  environment: UnsafeMutablePointer<JNIEnv?>!,
  thisClass: jclass,
  pointer: jlong
) -> jobject? {
  let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
  let box = Unmanaged<SwiftDictionaryBoxBase>.fromOpaque(rawPointer).takeUnretainedValue()
  return box.values(environment: environment)
}

@_cdecl("Java_org_swift_swiftkit_core_NativeSwiftDictionaryMap__00024destroy")
public func Java_NativeSwiftDictionaryMap_destroy(
  environment: UnsafeMutablePointer<JNIEnv?>!,
  thisClass: jclass,
  pointer: jlong
) {
  let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
  Unmanaged<SwiftDictionaryBoxBase>.fromOpaque(rawPointer).release()
}
