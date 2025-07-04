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

import JExtractSwiftLib
import Testing

@Suite
struct JNIModuleTests {
  let globalMethodWithPrimitives = """
    public func helloWorld()
    public func takeIntegers(i1: Int8, i2: Int16, i3: Int32, i4: Int64) -> UInt16
    public func otherPrimitives(b: Bool, f: Float, d: Double)
  """

  let globalMethodWithString = """
    public func copy(_ string: String) -> String
  """

  let globalMethodThrowing = """
    public func methodA() throws
    public func methodB() throws -> Int64
  """

  @Test
  func generatesModuleJavaClass() throws {
    let input = "public func helloWorld()"

    try assertOutput(input: input, .jni, .java, expectedChunks: [
      """
      // Generated by jextract-swift
      // Swift module: SwiftModule

      package com.example.swift;

      public final class SwiftModule {
        static final String LIB_NAME = "SwiftModule";
      
        static {
          System.loadLibrary(LIB_NAME);
        }
      """
    ])
  }

  @Test
  func globalMethodWithPrimitives_javaBindings() throws {
    try assertOutput(
      input: globalMethodWithPrimitives,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
          * Downcall to Swift:
          * {@snippet lang=swift :
          * public func helloWorld()
          * }
          */
        public static native void helloWorld();
        """,
        """
        /**
          * Downcall to Swift:
          * {@snippet lang=swift :
          * public func takeIntegers(i1: Int8, i2: Int16, i3: Int32, i4: Int64) -> UInt16
          * }
          */
        public static native char takeIntegers(byte i1, short i2, int i3, long i4);
        """,
        """
        /**
          * Downcall to Swift:
          * {@snippet lang=swift :
          * public func otherPrimitives(b: Bool, f: Float, d: Double)
          * }
          */
        public static native void otherPrimitives(boolean b, float f, double d);
        """
      ]
    )
  }

  @Test
  func globalMethodWithPrimitives_swiftThunks() throws {
    try assertOutput(
      input: globalMethodWithPrimitives,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule_helloWorld__")
        func Java_com_example_swift_SwiftModule_helloWorld__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) {
          SwiftModule.helloWorld()
        }
        """,
        """
        @_cdecl("Java_com_example_swift_SwiftModule_takeIntegers__BSIJ")
        func Java_com_example_swift_SwiftModule_takeIntegers__BSIJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, i1: jbyte, i2: jshort, i3: jint, i4: jlong) -> jchar {
          let result = SwiftModule.takeIntegers(i1: Int8(fromJNI: i1, in: environment!), i2: Int16(fromJNI: i2, in: environment!), i3: Int32(fromJNI: i3, in: environment!), i4: Int64(fromJNI: i4, in: environment!))
          return result.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_SwiftModule_otherPrimitives__ZFD")
        func Java_com_example_swift_SwiftModule_otherPrimitives__ZFD(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, b: jboolean, f: jfloat, d: jdouble) {
          SwiftModule.otherPrimitives(b: Bool(fromJNI: b, in: environment!), f: Float(fromJNI: f, in: environment!), d: Double(fromJNI: d, in: environment!))
        }
        """
      ]
    )
  }

  @Test
  func globalMethodWithString_javaBindings() throws {
    try assertOutput(
      input: globalMethodWithString,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
          * Downcall to Swift:
          * {@snippet lang=swift :
          * public func copy(_ string: String) -> String
          * }
          */
        public static native java.lang.String copy(java.lang.String string);
        """,
      ]
    )
  }

  @Test
  func globalMethodWithString_swiftThunks() throws {
    try assertOutput(
      input: globalMethodWithString,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
          """
          @_cdecl("Java_com_example_swift_SwiftModule_copy__Ljava_lang_String_2")
          func Java_com_example_swift_SwiftModule_copy__Ljava_lang_String_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, string: jstring?) -> jstring? {
            let result = SwiftModule.copy(String(fromJNI: string, in: environment!))
            return result.getJNIValue(in: environment)
          }
          """,
      ]
    )
  }

  @Test
  func globalMethodThrowing_javaBindings() throws {
    try assertOutput(
      input: globalMethodThrowing,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
          * Downcall to Swift:
          * {@snippet lang=swift :
          * public func methodA() throws
          * }
          */
        public static native void methodA() throws Exception;
        """,
        """
        /**
          * Downcall to Swift:
          * {@snippet lang=swift :
          * public func methodB() throws -> Int64
          * }
          */
        public static native long methodB() throws Exception;
        """,
      ]
    )
  }

  @Test
  func globalMethodThrowing_swiftThunks() throws {
    try assertOutput(
      input: globalMethodThrowing,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
          """
          @_cdecl("Java_com_example_swift_SwiftModule_methodA__")
          func Java_com_example_swift_SwiftModule_methodA__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) {
            do { 
              try SwiftModule.methodA()
            } catch {
              environment.throwAsException(error)
            }
          }
          """,
          """
          @_cdecl("Java_com_example_swift_SwiftModule_methodB__")
          func Java_com_example_swift_SwiftModule_methodB__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
            do { 
              let result = try SwiftModule.methodB()
              return result.getJNIValue(in: environment)
            } catch {
              environment.throwAsException(error)
              return Int64.jniPlaceholderValue
            }
          }
          """,
      ]
    )
  }
}
