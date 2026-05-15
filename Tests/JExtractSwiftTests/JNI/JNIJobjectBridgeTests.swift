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
struct JNIJobjectBridgeTests {
  @Test("JNI generates explicit bridges for dictionary element types")
  func generatesBridgeDeclaration() throws {
    try assertOutput(
      input: """
        public struct ReefFish {}
        public func f(dict: [Int: ReefFish]) -> [Int: ReefFish] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        private enum _JNI_ReefFish {
          private static let wrapMemoryAddressUnsafeMethod = _JNIMethodIDCache.Method(
            name: "wrapMemoryAddressUnsafe",
            signature: "(JLorg/swift/swiftkit/core/SwiftArena;)Lcom/example/swift/ReefFish;",
            isStatic: true
          )

          private static let cache = _JNIMethodIDCache(
            className: "com/example/swift/ReefFish",
            methods: [wrapMemoryAddressUnsafeMethod]
          )
          static var javaClass: jclass {
            cache.javaClass
          }
          static var wrapMemoryAddressUnsafe: jmethodID {
            cache[wrapMemoryAddressUnsafeMethod]!
          }
        """,
        """
        enum _JNIBridge_ReefFish: JextractedTypeBridge {
          typealias SwiftType = ReefFish

          static var javaClass: jclass {
            _JNI_ReefFish.javaClass
          } 

          static var wrapMemoryAddressUnsafe: jmethodID {
            _JNI_ReefFish.wrapMemoryAddressUnsafe
          }
        }
        """,
        """
        return SwiftModule.f(dict: [Int: ReefFish](fromJNI: dict, in: environment, keyBridge: JavaBoxableBridge<Int>.self, valueBridge: _JNIBridge_ReefFish.self)).dictionaryGetJNIValue(in: environment, keyBridge: JavaBoxableBridge<Int>.self, valueBridge: _JNIBridge_ReefFish.self)
        """,
      ]
    )
  }


  @Test("JNI generates explicit bridges for generic dictionary keys")
  func generatesBridgeDeclarationForGenericType() throws {
    try assertOutput(
      input: """
        public struct MyID<T: Hashable>: Hashable {}
        public func f() -> [MyID<Int>: String] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        enum _JNIBridge_MyID<T: Hashable>: JextractedGenericTypeBridge {
          typealias SwiftType = MyID<T>
        """,
        """
        return SwiftModule.f().dictionaryGetJNIValue(in: environment, keyBridge: _JNIBridge_MyID<Int>.self, valueBridge: JavaBoxableBridge<String>.self)
        """,
      ]
    )
  }
}
