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

import JavaTypes

/// A type used to represent a Java type that failed to import during swift-java importing.
/// This may be because the type was not known to swift-java, or because the Java type is not
/// representable in Swift.
///
/// See comments on the imported declaration containing this type for further details.
public struct SwiftJavaFailedImportType: JavaValue {
  public typealias JNIType = jobject?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public static var javaType: JavaType {
    .class(package: "java.lang", name: "Object")
  }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniMethodCall(in environment: JNIEnvironment) -> JNIMethodCall<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniStaticMethodCall(in environment: JNIEnvironment) -> JNIStaticMethodCall<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    fatalError("\(Self.self) is a placeholder type that means a type failed to import, and cannot be used at runtime!")
  }

  public static var jniPlaceholderValue: jstring? {
    nil
  }
}
