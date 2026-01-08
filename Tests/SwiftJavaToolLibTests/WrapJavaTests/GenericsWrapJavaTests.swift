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
import Subprocess
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

final class GenericsWrapJavaTests: XCTestCase {

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
        @JavaMethod(typeErasedResult: "KeyType!")
        open func getGeneric<KeyType: AnyJavaObject>(_ arg0: Item<KeyType>?) -> KeyType!
        """,
      ]
    )
  }

  // This is just a warning in Java, but a hard error in Swift, so we must 'prune' generic params
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
        @JavaMethod(typeErasedResult: "KeyType!")
        open func getGeneric<KeyType: AnyJavaObject>() -> KeyType!
        """,
      ]
    )
  }
  
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

  func test_Java2Swift_returnType_generic() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      // Mini decls in order to avoid warnings about some funcs we're not yet importing cleanly
      final class List<T> {}
      final class Map<T, U> {}
      final class Number {}

      class GenericClass<T> {
        public T getClassGeneric() { return null; }
        
        public <M> M getMethodGeneric() { return null; }

        public <M> Map<T, M> getMixedGeneric() { return null; }
        
        public String getNonGeneric() { return null; }

        public List<T> getParameterizedClassGeneric() { return null; }
        
        public List<? extends Number> getWildcard() { return null; }
        
        public T[] getGenericArray() { return null; }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Map",
        "com.example.List",
        "com.example.Number",
        "com.example.GenericClass",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaMethod(typeErasedResult: "T!")
        open func getClassGeneric() -> T!
        """,
        """
        @JavaMethod(typeErasedResult: "M!")
        open func getMethodGeneric<M: AnyJavaObject>() -> M!
        """,
        """
        @JavaMethod
        open func getMixedGeneric<M: AnyJavaObject>() -> Map<T, M>!
        """,
        """
        @JavaMethod
        open func getNonGeneric() -> String
        """,
        """
        @JavaMethod
        open func getParameterizedClassGeneric() -> List<T>!
        """,
        """
        @JavaMethod
        open func getWildcard() -> List<Number>!
        """,
        """
        @JavaMethod
        open func getGenericArray() -> [T?]
        """,
      ]
    )
  }

  func testWrapJavaGenericSuperclass() async throws {
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

  func test_wrapJava_genericMethodTypeErasure_returnType() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      final class Kappa<T> { 
        public T get() { return null; }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Kappa",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.Kappa")
        open class Kappa<T: AnyJavaObject>: JavaObject {
          @JavaMethod(typeErasedResult: "T!")
          open func get() -> T!
        }
        """
      ]
    )
  }
  
  func test_wrapJava_genericMethodTypeErasure_ofNullableOptional_staticMethods() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      final class Optional<T> {
        public static <T> Optional<T> ofNullable(T value) { return null; }
        
        public static <T> T nonNull(T value) { return null; }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Optional"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaClass("com.example.Optional")
        open class Optional<T: AnyJavaObject>: JavaObject {
        """,
        """
        extension JavaClass {
        """,
        """
        @JavaStaticMethod
        public func ofNullable<T: AnyJavaObject>(_ arg0: T?) -> Optional<T>! where ObjectType == Optional<T>
        }
        """,
        """
        @JavaStaticMethod(typeErasedResult: "T!")
        public func nonNull<T: AnyJavaObject>(_ arg0: T?) -> T! where ObjectType == Optional<T>
        """
      ]
    )
  }

  func test_wrapJava_genericMethodTypeErasure_customInterface_staticMethods() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;
      
      interface MyInterface {}

      final class Public {
        public static <T extends MyInterface> void useInterface(T myInterface) {  }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.MyInterface",
        "com.example.Public"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaInterface("com.example.MyInterface")
        public struct MyInterface {
        """,
        """
        @JavaClass("com.example.Public")
        open class Public: JavaObject {
        """,
        """
        extension JavaClass<Public> {
        """,
        """
        @JavaStaticMethod
        public func useInterface<T: AnyJavaObject>(_ arg0: T?)
        }
        """
      ]
    )
  }

  // TODO: this should be improved some more, we need to generated a `: Map` on the Swift side
  func test_wrapJava_genericMethodTypeErasure_genericExtendsMap() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;
      
      final class Map<T, U> {}
      
      final class Something {
        public <M extends Map<String, String>> M putIn(M map) { return null; }
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Map",
        "com.example.Something",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaClass("com.example.Something")
        open class Something: JavaObject {
        """,
        """
        @JavaMethod(typeErasedResult: "M!")
        open func putIn<M: AnyJavaObject>(_ arg0: M?) -> M!
        """,
      ]
    )
  }
  
}
