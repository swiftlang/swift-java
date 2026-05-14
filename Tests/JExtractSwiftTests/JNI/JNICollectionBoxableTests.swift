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
  @Test("JNI generates explicit bridges for dictionary element types")
  func generatesBridgeDeclaration() throws {
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
        private enum _JNI_ReefFish {
          private static let wrapMemoryAddressUnsafeMethod = _JNIMethodIDCache.Method(
            name: "wrapMemoryAddressUnsafe",
            signature: "(JLorg/swift/swiftkit/core/SwiftArena;)Lcom/example/swift/ReefFish;",
            isStatic: true
          )
        """,
        """
        enum _SwiftJavaBridge_ReefFish: JextractedTypeBridge {
          typealias SwiftType = ReefFish
          static var javaClass: jclass {
            _JNI_ReefFish.javaClass
          }
          static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
            let selfPointer$ = UnsafeMutablePointer<SwiftType>.allocate(capacity: 1)
            selfPointer$.initialize(to: value)
            let selfPointerBits$ = Int64(Int(bitPattern: selfPointer$))
            var args = [jvalue(), jvalue()]
            args[0].j = selfPointerBits$.getJNIValue(in: environment)
            args[1].l = JavaSwiftArena.defaultAutoArena.javaThis
            return environment.interface.CallStaticObjectMethodA(
              environment,
              _JNI_ReefFish.javaClass,
              _JNI_ReefFish.wrapMemoryAddressUnsafe,
              &args
            )
          }
          ...
          static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType {
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
            guard let valuePointer$ = UnsafeMutablePointer<SwiftType>(bitPattern: selfPointerBits$) else {
              fatalError("ReefFish.fromJavaObject received a null Swift memory address")
            }
            return valuePointer$.pointee
          }
        }
        """,
        """
        return SwiftModule.f(dict: [Int: ReefFish].init(fromJNI: dict, in: environment, keyBridge: JavaBoxableBridge<Int>.self, valueBridge: _SwiftJavaBridge_ReefFish.self)).dictionaryGetJNIValue(in: environment, keyBridge: JavaBoxableBridge<Int>.self, valueBridge: _SwiftJavaBridge_ReefFish.self)
        """,
      ]
    )
  }


  @Test("JNI generates explicit bridges for generic dictionary keys")
  func generatesBridgeDeclarationForGenericType() throws {
    try assertOutput(
      input: """
        public struct MyID<T>: Hashable {}
        public func f() -> [MyID<Int>: String] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        private enum _JNI_MyID {
          private static let wrapMemoryAddressUnsafeMethod = _JNIMethodIDCache.Method(
            name: "wrapMemoryAddressUnsafe",
            signature: "(JJLorg/swift/swiftkit/core/SwiftArena;)Lcom/example/swift/MyID;",
            isStatic: true
          )
        """,
        """
        enum _SwiftJavaBridge_MyID<T>: JextractedTypeBridge {
          typealias SwiftType = MyID<T>
          static var javaClass: jclass {
            _JNI_MyID.javaClass
          }
          static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
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
              _JNI_MyID.javaClass,
              _JNI_MyID.wrapMemoryAddressUnsafe,
              &args
            )
          }
          ...
          static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType {
            guard let obj else {
              fatalError("MyID<T>.fromJavaObject received a null Java object")
            }
            let selfPointer$ = environment.interface.CallLongMethodA(
              environment,
              obj,
              _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
              nil
            )
            let selfPointerBits$ = Int(Int64(fromJNI: selfPointer$, in: environment))
            guard let valuePointer$ = UnsafeMutablePointer<SwiftType>(bitPattern: selfPointerBits$) else {
              fatalError("MyID<T>.fromJavaObject received a null Swift memory address")
            }
            return valuePointer$.pointee
          }
        }
        """,
        """
        return SwiftModule.f().dictionaryGetJNIValue(in: environment, keyBridge: _SwiftJavaBridge_MyID<Int>.self, valueBridge: JavaBoxableBridge<String>.self)
        """,
      ]
    )
  }
}
