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
struct JNIGenericCombinationTests {
  static let myIDDecl =
    #"""
    public struct MyID<T> {
      public var rawValue: T
      public init(_ rawValue: T) {
        self.rawValue = rawValue  
      }
      public var description: String {
        "\(rawValue)"
      }
    }
    """#

  @Suite struct WithOptional {
    let returnFuncFile = """
      \(myIDDecl)
        
      public func makeStringIDOptional(_ value: String) -> MyID<String>? {
        return MyID(value)
      }
      """

    let argumentFuncFile = """
      \(myIDDecl)
        
      public func takeStringIDOptional(_ value: MyID<String>?) {
      }
      """

    @Test
    func returnFuncJava() throws {
      try assertOutput(
        input: returnFuncFile,
        .jni,
        .java,
        detectChunkByInitialLines: 2,
        expectedChunks: [
          """
          public static Optional<MyID<java.lang.String>> makeStringIDOptional(java.lang.String value, SwiftArena swiftArena) {
            byte[] result$_discriminator$ = new byte[1];
            org.swift.swiftkit.core._OutSwiftGenericInstance resultWrapped$ = new org.swift.swiftkit.core._OutSwiftGenericInstance();
            SwiftModule.$makeStringIDOptional(value, result$_discriminator$, resultWrapped$);
            return (result$_discriminator$[0] == 1) ? Optional.of(MyID.<java.lang.String>wrapMemoryAddressUnsafe(resultWrapped$.selfPointer, resultWrapped$.selfTypePointer, swiftArena)) : Optional.empty();
          }
          """,
          """
          private static native void $makeStringIDOptional(java.lang.String value, byte[] result_discriminator$, org.swift.swiftkit.core._OutSwiftGenericInstance resultWrappedOut);
          """,
        ]
      )
    }

    @Test
    func returnFuncSwift() throws {
      try assertOutput(
        input: returnFuncFile,
        .jni,
        .swift,
        detectChunkByInitialLines: 2,
        expectedChunks: [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024makeStringIDOptional__Ljava_lang_String_2_3BLorg_swift_swiftkit_core__1OutSwiftGenericInstance_2")
          public func Java_com_example_swift_SwiftModule__00024makeStringIDOptional__Ljava_lang_String_2_3BLorg_swift_swiftkit_core__1OutSwiftGenericInstance_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jstring?, result_discriminator$: jbyteArray?, resultWrappedOut: jobject?) {
            if let innerResult$ = SwiftModule.makeStringIDOptional(String(fromJNI: value, in: environment)) {
              let resultWrapped$ = UnsafeMutablePointer<MyID<String>>.allocate(capacity: 1)
              resultWrapped$.initialize(to: innerResult$)
              let resultWrappedBits$ = Int64(Int(bitPattern: resultWrapped$))
              do {
               environment.interface.SetLongField(environment, resultWrappedOut, _JNIMethodIDCache._OutSwiftGenericInstance.selfPointer, resultWrappedBits$.getJNIValue(in: environment))
               let metadataPointer = unsafeBitCast(MyID<String>.self, to: UnsafeRawPointer.self)
               let metadataPointerBits$ = Int64(Int(bitPattern: metadataPointer))
               environment.interface.SetLongField(environment, resultWrappedOut, _JNIMethodIDCache._OutSwiftGenericInstance.selfTypePointer, metadataPointerBits$.getJNIValue(in: environment))
              }
              var flag$ = Int8(1)
              environment.interface.SetByteArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
            } 
            else {
              var flag$ = Int8(0)
              environment.interface.SetByteArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
            }
            return 
          }
          """
        ]
      )
    }

    @Test
    func argumentFuncJava() throws {
      try assertOutput(
        input: argumentFuncFile,
        .jni,
        .java,
        detectChunkByInitialLines: 2,
        expectedChunks: [
          """
          public static void takeStringIDOptional(Optional<MyID<java.lang.String>> value) {
            SwiftModule.$takeStringIDOptional(value.map(MyID<java.lang.String>::$memoryAddress).orElse(0L));
          }
          """,
          """
          private static native void $takeStringIDOptional(long value);
          """,
        ]
      )
    }

    @Test
    func argumentFuncSwift() throws {
      try assertOutput(
        input: argumentFuncFile,
        .jni,
        .swift,
        detectChunkByInitialLines: 2,
        expectedChunks: [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024takeStringIDOptional__J")
          public func Java_com_example_swift_SwiftModule__00024takeStringIDOptional__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) {
            let valueBits$ = Int(Int64(fromJNI: value, in: environment))
            let value$ = UnsafeMutablePointer<MyID<String>>(bitPattern: valueBits$)
            SwiftModule.takeStringIDOptional(value$?.pointee)
          }
          """
        ]
      )
    }
  }

  @Suite struct WithTuple {
    let returnFuncFile = """
      \(myIDDecl)
        
      public static func makeIDs(_ stringValue: String, _ intValue: Int64) -> (MyID<String>, MyID<Int64>) {
        (MyID(stringValue), MyID(intValue))
      }
      """

    let argumentFuncFile = """
      \(myIDDecl)
        
      public static func takeValues(from tuple: (MyID<String>, MyID<Int64>)) -> (String, Int64) {
        (tuple.0.rawValue, tuple.1.rawValue)
      }
      """

    @Test
    func returnFuncJava() throws {
      try assertOutput(
        input: returnFuncFile,
        .jni,
        .java,
        detectChunkByInitialLines: 2,
        expectedChunks: [
          """
          public static org.swift.swiftkit.core.tuple.Tuple2<MyID<java.lang.String>, MyID<java.lang.Long>> makeIDs(java.lang.String stringValue, long intValue, SwiftArena swiftArena) {
            org.swift.swiftkit.core._OutSwiftGenericInstance result_0$ = new org.swift.swiftkit.core._OutSwiftGenericInstance();
            org.swift.swiftkit.core._OutSwiftGenericInstance result_1$ = new org.swift.swiftkit.core._OutSwiftGenericInstance();
            SwiftModule.$makeIDs(stringValue, intValue, result_0$, result_1$);
            var result_0 = MyID.<java.lang.String>wrapMemoryAddressUnsafe(result_0$.selfPointer, result_0$.selfTypePointer, swiftArena);
            var result_1 = MyID.<java.lang.Long>wrapMemoryAddressUnsafe(result_1$.selfPointer, result_1$.selfTypePointer, swiftArena);
            return new org.swift.swiftkit.core.tuple.Tuple2<MyID<java.lang.String>, MyID<java.lang.Long>>(result_0, result_1);
          }
          """,
          """
          private static native void $makeIDs(java.lang.String stringValue, long intValue, org.swift.swiftkit.core._OutSwiftGenericInstance result_0$Out, org.swift.swiftkit.core._OutSwiftGenericInstance result_1$Out);
          """,
        ]
      )
    }

    @Test
    func returnFuncSwift() throws {
      try assertOutput(
        input: returnFuncFile,
        .jni,
        .swift,
        detectChunkByInitialLines: 4,
        expectedChunks: [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024makeIDs__Ljava_lang_String_2JLorg_swift_swiftkit_core__1OutSwiftGenericInstance_2Lorg_swift_swiftkit_core__1OutSwiftGenericInstance_2")
          public func Java_com_example_swift_SwiftModule__00024makeIDs__Ljava_lang_String_2JLorg_swift_swiftkit_core__1OutSwiftGenericInstance_2Lorg_swift_swiftkit_core__1OutSwiftGenericInstance_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, stringValue: jstring?, intValue: jlong, result_0$Out: jobject?, result_1$Out: jobject?) {
            let tupleResult$ = SwiftModule.makeIDs(String(fromJNI: stringValue, in: environment), Int64(fromJNI: intValue, in: environment))
            let result_0$$ = UnsafeMutablePointer<MyID<String>>.allocate(capacity: 1)
            result_0$$.initialize(to: tupleResult$.0)
            let result_0$Bits$ = Int64(Int(bitPattern: result_0$$))
            do {
              environment.interface.SetLongField(environment, result_0$Out, _JNIMethodIDCache._OutSwiftGenericInstance.selfPointer, result_0$Bits$.getJNIValue(in: environment))
              let metadataPointer = unsafeBitCast(MyID<String>.self, to: UnsafeRawPointer.self)
              let metadataPointerBits$ = Int64(Int(bitPattern: metadataPointer))
              environment.interface.SetLongField(environment, result_0$Out, _JNIMethodIDCache._OutSwiftGenericInstance.selfTypePointer, metadataPointerBits$.getJNIValue(in: environment))
            }
            let result_1$$ = UnsafeMutablePointer<MyID<Int64>>.allocate(capacity: 1)
            result_1$$.initialize(to: tupleResult$.1)
            let result_1$Bits$ = Int64(Int(bitPattern: result_1$$))
            do {
              environment.interface.SetLongField(environment, result_1$Out, _JNIMethodIDCache._OutSwiftGenericInstance.selfPointer, result_1$Bits$.getJNIValue(in: environment))
              let metadataPointer = unsafeBitCast(MyID<Int64>.self, to: UnsafeRawPointer.self)
              let metadataPointerBits$ = Int64(Int(bitPattern: metadataPointer))
              environment.interface.SetLongField(environment, result_1$Out, _JNIMethodIDCache._OutSwiftGenericInstance.selfTypePointer, metadataPointerBits$.getJNIValue(in: environment))
            }
            return 
          }
          """
        ]
      )
    }

    @Test
    func argumentFuncJava() throws {
      try assertOutput(
        input: argumentFuncFile,
        .jni,
        .java,
        detectChunkByInitialLines: 2,
        expectedChunks: [
          """
          public static org.swift.swiftkit.core.tuple.Tuple2<java.lang.String, java.lang.Long> takeValues(org.swift.swiftkit.core.tuple.Tuple2<MyID<java.lang.String>, MyID<java.lang.Long>> tuple) {
            java.lang.String[] result_0$ = new java.lang.String[1];
            long[] result_1$ = new long[1];
            SwiftModule.$takeValues(tuple.$0.$memoryAddress(), tuple.$1.$memoryAddress(), result_0$, result_1$);
            return new org.swift.swiftkit.core.tuple.Tuple2<java.lang.String, java.lang.Long>(result_0$[0], result_1$[0]);
          }
          """,
          """
          private static native void $takeValues(long tuple_0, long tuple_1, java.lang.String[] result_0$, long[] result_1$);
          """,
        ]
      )
    }

    @Test
    func argumentFuncSwift() throws {
      try assertOutput(
        input: argumentFuncFile,
        .jni,
        .swift,
        detectChunkByInitialLines: 2,
        expectedChunks: [
          #"""
          @_cdecl("Java_com_example_swift_SwiftModule__00024takeValues__JJ_3Ljava_lang_String_2_3J")
          public func Java_com_example_swift_SwiftModule__00024takeValues__JJ_3Ljava_lang_String_2_3J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, tuple_0: jlong, tuple_1: jlong, result_0$: jobjectArray?, result_1$: jlongArray?) {
            assert(tuple_0 != 0, "tuple_0 memory address was null")
            let tuple_0Bits$ = Int(Int64(fromJNI: tuple_0, in: environment))
            let tuple_0$ = UnsafeMutablePointer<MyID<String>>(bitPattern: tuple_0Bits$)
            guard let tuple_0$ else {
              fatalError("tuple_0 memory address was null in call to \(#function)!")
            }
            assert(tuple_1 != 0, "tuple_1 memory address was null")
            let tuple_1Bits$ = Int(Int64(fromJNI: tuple_1, in: environment))
            let tuple_1$ = UnsafeMutablePointer<MyID<Int64>>(bitPattern: tuple_1Bits$)
            guard let tuple_1$ else {
              fatalError("tuple_1 memory address was null in call to \(#function)!")
            }
            let tupleResult$ = SwiftModule.takeValues(from: (tuple_0$.pointee, tuple_1$.pointee))
            let element_0_jni$ = tupleResult$.0.getJNILocalRefValue(in: environment)
            environment.interface.SetObjectArrayElement(environment, result_0$, 0, element_0_jni$)
            var element_1_jni$ = tupleResult$.1.getJNILocalRefValue(in: environment)
            environment.interface.SetLongArrayRegion(environment, result_1$, 0, 1, &element_1_jni$)
            return 
          }
          """#
        ]
      )
    }
  }

}
