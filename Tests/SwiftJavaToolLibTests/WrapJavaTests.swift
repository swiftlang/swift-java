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

@_spi(Testing) import SwiftJava
import SwiftJavaToolLib
import JavaUtilJar
import SwiftJavaShared
import JavaNet
import SwiftJavaConfigurationShared
import _Subprocess
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

final class WrapJavaTests: XCTestCase {

  // @Test
  func testWrapJavaFromCompiledJavaSource() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class ExampleSimpleClass {}
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.ExampleSimpleClass")
        open class ExampleSimpleClass: JavaObject {
        """
      ]
    )
  }

  // @Test
  func testWrapJavaGenericMethod_singleGeneric() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class Item<T> { 
        final T value;
        Item(T item) {
          this.value = item;
        }
      }
      class Pair<First, Second> { }

      class ExampleSimpleClass {
        <KeyType> KeyType getGeneric(Item<KeyType> key) { return null; }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Item",
        "com.example.Pair",
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.Pair")
        open class Pair<First: AnyJavaObject, Second: AnyJavaObject>: JavaObject {
        """,
        """
        @JavaClass("com.example.ExampleSimpleClass")
        open class ExampleSimpleClass: JavaObject {
        """,
        """
        @JavaMethod
        open func getGeneric<KeyType: AnyJavaObject>(_ arg0: Item<KeyType>?) -> KeyType
        """,
      ]
    )
  }

  // This is just a warning in Java, but a hard error in Swift, so we must 'prune' generic params
  // @Test
  func testWrapJavaGenericMethod_pruneNotUsedGenericParam() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class Item<T> { 
        final T value;
        Item(T item) {
          this.value = item;
        }
      }
      class Pair<First, Second> { }

      final class ExampleSimpleClass {
        // use in return type
        <KeyType, NotUsedParam> KeyType getGeneric() { 
          return null;
        }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Item",
        "com.example.Pair",
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaMethod
        open func getGeneric<KeyType: AnyJavaObject>() -> KeyType
        """,
      ]
    )
  }
  
  // @Test
  func testWrapJavaGenericMethod_multipleGenerics() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class Item<T> { 
        final T value;
        Item(T item) {
          this.value = item;
        }
      }
      class Pair<First, Second> { }

      class ExampleSimpleClass {
        <KeyType, ValueType> Pair<KeyType, ValueType> getPair(String name, Item<KeyType> key, Item<ValueType> value) { return null; }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Item",
        "com.example.Pair",
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.Item")
        open class Item<T: AnyJavaObject>: JavaObject {
        """,
        """
        @JavaClass("com.example.Pair")
        open class Pair<First: AnyJavaObject, Second: AnyJavaObject>: JavaObject {
        """,
        """
        @JavaClass("com.example.ExampleSimpleClass")
        open class ExampleSimpleClass: JavaObject {
        """,
        """
        @JavaMethod
        open func getPair<KeyType: AnyJavaObject, ValueType: AnyJavaObject>(_ arg0: String, _ arg1: Item<KeyType>?, _ arg2: Item<ValueType>?) -> Pair<KeyType, ValueType>!
        """,
      ]
    )
  }

  /*
  /Users/ktoso/code/voldemort-swift-java/.build/plugins/outputs/voldemort-swift-java/VoldemortSwiftJava/destination/SwiftJavaPlugin/generated/CompressingStore.swift:6:30: error: reference to generic type 'AbstractStore' requires arguments in <...>
 4 |
 5 | @JavaClass("voldemort.store.compress.CompressingStore")
 6 | open class CompressingStore: AbstractStore {
   |                              `- error: reference to generic type 'AbstractStore' requires arguments in <...>
 7 |   @JavaMethod
 8 |   open override func getCapability(_ arg0: StoreCapabilityType?) -> JavaObject!

/Users/ktoso/code/voldemort-swift-java/.build/plugins/outputs/voldemort-swift-java/VoldemortSwiftJava/destination/SwiftJavaPlugin/generated/AbstractStore.swift:6:12: note: generic type 'AbstractStore' declared here
 4 |
 5 | @JavaClass("voldemort.store.AbstractStore", implements: Store<JavaObject, JavaObject, JavaObject>.self)
 6 | open class AbstractStore<K: AnyJavaObject, V: AnyJavaObject, T: AnyJavaObject>: JavaObject {
   |            `- note: generic type 'AbstractStore' declared here
 7 |   @JavaMethod
 8 |   @_nonoverride public convenience init(_ arg0: String, environment: JNIEnvironment? = nil)
  */
  // @Test
  func testGenericSuperclass() async throws {
    return  // FIXME: we need this 

    let classpathURL = try await compileJava(
      """
      package com.example;

      class ByteArray {}
      class CompressingStore extends AbstractStore<ByteArray, byte[], byte[]> {}
      abstract class AbstractStore<K, V, T> {} // implements Store<K, V, T> {}
      // interface Store<K, V, T> {}

      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ByteArray",
        // TODO: what if we visit in other order, does the wrap-java handle it
        // "com.example.Store",
        "com.example.AbstractStore",
        "com.example.CompressingStore",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.ByteArray")
        open class ByteArray: JavaObject {
        """,
        // """
        // @JavaInterface("com.example.Store")
        // public struct Store<K: AnyJavaObject, V: AnyJavaObject, T: AnyJavaObject> {
        // """,
        """
        @JavaClass("com.example.CompressingStore")
        open class CompressingStore: AbstractStore<ByteArray, [UInt8], [UInt8]> {
        """
      ]
    )
  }
}
