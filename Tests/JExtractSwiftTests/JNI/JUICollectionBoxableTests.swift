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

import JExtractSwiftLib
import Testing

@Suite
struct JUICollectionBoxableTests {
  @Test("JNI generates JavaValue and JavaBoxable for dictionary element types")
  func dictionaryCustomValueGeneratesJavaBoxingConformance() throws {
    try assertOutput(
      input: """
        public struct ReefFish: Hashable {}
        public func f(dict: [Int: ReefFish]) -> [Int: ReefFish] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__J")
        public func Java_com_example_swift_SwiftModule__00024f__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, dict: jlong) -> jlong {
          return SwiftModule.f(dict: [Int: ReefFish](fromJNI: dict, in: environment)).dictionaryGetJNIValue(in: environment)
        }
        """,
        """
        private enum _SwiftJavaBoxing_ReefFish {
          private static let wrapMemoryAddressUnsafeMethod = _JNIMethodIDCache.Method(
            name: "wrapMemoryAddressUnsafe",
            signature: "(J)Lcom/example/swift/ReefFish;",
            isStatic: true
          )
          ...
        }
        """,
        """
        extension ReefFish: JavaValue, JavaBoxable {
          public typealias JNIType = jobject?
          public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \\.l }
          public static var javaType: JavaType { JavaType(className: "com.example.swift.ReefFish") }
          public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
            toJavaObject(in: environment)
          }
          public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
            let selfPointer$ = UnsafeMutablePointer<ReefFish>.allocate(capacity: 1)
            selfPointer$.initialize(to: self)
            let selfPointerBits$ = Int64(Int(bitPattern: selfPointer$))
            var args = [jvalue()]
            args[0].j = selfPointerBits$.getJNIValue(in: environment)
            return environment.interface.CallStaticObjectMethodA(
              environment,
              _SwiftJavaBoxing_ReefFish.javaClass,
              _SwiftJavaBoxing_ReefFish.wrapMemoryAddressUnsafe,
              &args
            )
          }
          ...
          public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> ReefFish {
            guard let obj else {
              fatalError("ReefFish.fromJavaObject received a null Java object")
            }
            let selfPointer$ = environment.interface.CallLongMethodA(
              environment,
              obj,
              _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
              nil
            )
            let selfPointerBits$ = Int(Int64(fromJNI: selfPointer$, in: environment))
            guard let valuePointer$ = UnsafeMutablePointer<ReefFish>(bitPattern: selfPointerBits$) else {
              fatalError("ReefFish.fromJavaObject received a null Swift memory address")
            }
            return valuePointer$.pointee
          }
          ...
          public static var jniPlaceholderValue: JNIType { nil }
        }
        """,
      ]
    )
  }

  @Test("JNI generates JavaValue and JavaBoxable for set element types")
  func setCustomElementGeneratesJavaBoxingConformance() throws {
    try assertOutput(
      input: """
        public struct ReefFish: Hashable {}
        public func f(set: Set<ReefFish>) -> Set<ReefFish> {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__J")
        public func Java_com_example_swift_SwiftModule__00024f__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, set: jlong) -> jlong {
          return SwiftModule.f(set: Set<ReefFish>(fromJNI: set, in: environment)).setGetJNIValue(in: environment)
        }
        """,
        """
        extension ReefFish: JavaValue, JavaBoxable {
          public typealias JNIType = jobject?
          public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \\.l }
          public static var javaType: JavaType { JavaType(className: "com.example.swift.ReefFish") }
          public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
            toJavaObject(in: environment)
          }
          public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
            let selfPointer$ = UnsafeMutablePointer<ReefFish>.allocate(capacity: 1)
            selfPointer$.initialize(to: self)
            let selfPointerBits$ = Int64(Int(bitPattern: selfPointer$))
            var args = [jvalue()]
            args[0].j = selfPointerBits$.getJNIValue(in: environment)
            return environment.interface.CallStaticObjectMethodA(
              environment,
              _SwiftJavaBoxing_ReefFish.javaClass,
              _SwiftJavaBoxing_ReefFish.wrapMemoryAddressUnsafe,
              &args
            )
          }
          ...
          public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> ReefFish {
            guard let obj else {
              fatalError("ReefFish.fromJavaObject received a null Java object")
            }
            let selfPointer$ = environment.interface.CallLongMethodA(
              environment,
              obj,
              _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
              nil
            )
            let selfPointerBits$ = Int(Int64(fromJNI: selfPointer$, in: environment))
            guard let valuePointer$ = UnsafeMutablePointer<ReefFish>(bitPattern: selfPointerBits$) else {
              fatalError("ReefFish.fromJavaObject received a null Swift memory address")
            }
            return valuePointer$.pointee
          }
          ...
          public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
            { environment, size in environment.interface.NewObjectArray(environment, size, _SwiftJavaBoxing_ReefFish.javaClass, nil) }
          }
          ...
        }
        """,
      ]
    )
  }
}
