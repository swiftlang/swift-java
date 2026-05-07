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
struct JNICollectionBoxableTests {
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
            let selfPointer$ = UnsafeMutablePointer<Self>.allocate(capacity: 1)
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
          public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Self {
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
            guard let valuePointer$ = UnsafeMutablePointer<Self>(bitPattern: selfPointerBits$) else {
              fatalError("ReefFish.fromJavaObject received a null Swift memory address")
            }
            return valuePointer$.pointee
          }
          ...
          public static var jniPlaceholderValue: JNIType { nil }
        }
        """,
      ],
      notExpectedChunks: ["private enum _SwiftJavaCollectionJavaBoxingCache"]
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
            let selfPointer$ = UnsafeMutablePointer<Self>.allocate(capacity: 1)
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
          public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Self {
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
            guard let valuePointer$ = UnsafeMutablePointer<Self>(bitPattern: selfPointerBits$) else {
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
      ],
      notExpectedChunks: ["private enum _SwiftJavaCollectionJavaBoxingCache"]
    )
  }

  @Test("JNI uses runtime support cache for nested dictionary boxing")
  func nestedDictionaryUsesRuntimeSupportCache() throws {
    try assertOutput(
      input: """
        public struct ReefFish: Hashable {}
        public func f(dict: [String: [Int: ReefFish]]) -> [String: [Int: ReefFish]] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        extension [Int: ReefFish]: JavaValue, JavaBoxable {
          ...
          let selfPointer$ = self.dictionaryGetJNIValue(in: environment)
          var args = [jvalue(), jvalue()]
          args[0].j = selfPointer$
          args[1].l = JavaSwiftArena.defaultAutoArena.javaThis
          return environment.interface.CallStaticObjectMethodA(
            environment,
            _JNIMethodIDCache.SwiftDictionaryMap.class,
            _JNIMethodIDCache.SwiftDictionaryMap.wrapMemoryAddressUnsafe,
            &args
          )
          ...
        }
        """,
      ],
      notExpectedChunks: ["private enum _SwiftJavaCollectionJavaBoxingCache"]
    )
  }

  @Test("JNI uses runtime support cache for nested set boxing")
  func nestedSetUsesRuntimeSupportCache() throws {
    try assertOutput(
      input: """
        public struct ReefFish: Hashable {}
        public func f(dict: [String: Set<ReefFish>]) -> [String: Set<ReefFish>] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        extension Set<ReefFish>: JavaValue, JavaBoxable {
          ...
          let selfPointer$ = self.setGetJNIValue(in: environment)
          var args = [jvalue(), jvalue()]
          args[0].j = selfPointer$
          args[1].l = JavaSwiftArena.defaultAutoArena.javaThis
          return environment.interface.CallStaticObjectMethodA(
            environment,
            _JNIMethodIDCache.SwiftSet.class,
            _JNIMethodIDCache.SwiftSet.wrapMemoryAddressUnsafe,
            &args
          )
          ...
        }
        """,
      ],
      notExpectedChunks: ["private enum _SwiftJavaCollectionJavaBoxingCache"]
    )
  }

  @Test("JNI generates JavaBoxable for generic dictionary keys")
  func genericDictionaryKeyGeneratesJavaBoxingConformance() throws {
    try assertOutput(
      input: """
        public struct Fish: Hashable {}
        public struct MyID<T>: Hashable {}
        public func f() -> [MyID<Int>: Fish] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        private enum _SwiftJavaBoxing_MyID {
          private static let wrapMemoryAddressUnsafeMethod = _JNIMethodIDCache.Method(
            name: "wrapMemoryAddressUnsafe",
            signature: "(JJ)Lcom/example/swift/MyID;",
            isStatic: true
          )
          ...
        }
        """,
        """
        extension MyID: JavaValue, JavaBoxable {
          public typealias JNIType = jobject?
          public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \\.l }
          public static var javaType: JavaType { JavaType(className: "com.example.swift.MyID") }
          public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
            toJavaObject(in: environment)
          }
          public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
            let selfPointer$ = UnsafeMutablePointer<Self>.allocate(capacity: 1)
            selfPointer$.initialize(to: self)
            let selfPointerBits$ = Int64(Int(bitPattern: selfPointer$))
            let selfTypePointer$ = unsafeBitCast(Self.self, to: UnsafeRawPointer.self)
            let selfTypePointerBits$ = Int64(Int(bitPattern: selfTypePointer$))
            var args = [jvalue(), jvalue()]
            args[0].j = selfPointerBits$.getJNIValue(in: environment)
            args[1].j = selfTypePointerBits$.getJNIValue(in: environment)
            return environment.interface.CallStaticObjectMethodA(
              environment,
              _SwiftJavaBoxing_MyID.javaClass,
              _SwiftJavaBoxing_MyID.wrapMemoryAddressUnsafe,
              &args
            )
          }
          ...
          public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Self {
            guard let obj else {
              fatalError("MyID.fromJavaObject received a null Java object")
            }
            let selfPointer$ = environment.interface.CallLongMethodA(
              environment,
              obj,
              _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
              nil
            )
            let selfPointerBits$ = Int(Int64(fromJNI: selfPointer$, in: environment))
            guard let valuePointer$ = UnsafeMutablePointer<Self>(bitPattern: selfPointerBits$) else {
              fatalError("MyID.fromJavaObject received a null Swift memory address")
            }
            return valuePointer$.pointee
          }
          ...
        }
        """,
      ]
    )
  }
}
