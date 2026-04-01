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
struct JNIGenericTypeTests {
  let genericFile =
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

    public func makeStringID(_ value: String) -> MyID<String> {
      return MyID(value)
    }

    public func takeIntID(_ value: MyID<Int>) -> Int {
      return value.rawValue
    }
    """#

  @Test
  func generateJavaClass() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public final class MyID<T> implements JNISwiftInstance {
        """,
        """
        private MyID(long selfPointer, long selfTypePointer, SwiftArena swiftArena) {
        """,
        """
        public static<T> MyID<T> wrapMemoryAddressUnsafe(long selfPointer, long selfTypePointer, SwiftArena swiftArena) {
          return new MyID<T>(selfPointer, selfTypePointer, swiftArena);
        }

        public static<T> MyID<T> wrapMemoryAddressUnsafe(long selfPointer, long selfTypePointer) {
          return new MyID<T>(selfPointer, selfTypePointer, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA);
        }
        """,
        """
        private final long selfTypePointer;
        """,
        """
        public java.lang.String getDescription() {
          return MyID.$getDescription(this.$memoryAddress(), this.$typeMetadataAddress());
        }
        private static native java.lang.String $getDescription(long selfPointer, long selfTypePointer);
        """,
        """
        @Override
        public long $typeMetadataAddress() {
          return this.selfTypePointer;
        }
        """,
        """
        @Override
        public Runnable $createDestroyFunction() {
          long self$ = this.$memoryAddress();
          long selfType$ = this.$typeMetadataAddress();
          if (CallTraces.TRACE_DOWNCALLS) {
            CallTraces.traceDowncall("MyID.$createDestroyFunction",
              "this", this,
              "self", self$,
              "selfType", selfType$);
          }
          return new Runnable() {
            @Override
            public void run() {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall("MyID.$destroy", "self", self$, "selfType", selfType$);
              }
              SwiftObjects.destroy(self$, selfType$);
            }
          };
        }
        """,
      ]
    )
  }

  @Test
  func generateSwiftThunk() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        protocol _SwiftModule_MyID_opener {
          static func _get_description(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jstring?
          ...
        }
        """,
        #"""
        extension MyID: _SwiftModule_MyID_opener {
          static func _get_description(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jstring? {
            assert(selfPointer != 0, "selfPointer memory address was null")
            let selfPointerBits$ = Int(fromJNI: selfPointer, in: environment)
            let selfPointer$ = UnsafeMutablePointer<MyID>(bitPattern: selfPointerBits$)
            guard let selfPointer$ else {
              fatalError("selfPointer memory address was null in call to \(#function)!")
            }
            return selfPointer$.pointee.description.getJNILocalRefValue(in: environment)
          }
          ...
        }
        """#,
        """
        @_cdecl("Java_com_example_swift_MyID__00024getDescription__JJ")
        public func Java_com_example_swift_MyID__00024getDescription__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, selfTypePointer: jlong) -> jstring? {
          let selfTypePointerBits$ = Int(fromJNI: selfTypePointer, in: environment)
          guard let selfTypePointer$ = UnsafeRawPointer(bitPattern: selfTypePointerBits$) else {
            fatalError("selfTypePointer metadata address was null")
          }
          let openerType = unsafeBitCast(selfTypePointer$, to: Any.Type.self) as! (any _SwiftModule_MyID_opener.Type)
          return openerType._get_description(environment: environment, thisClass: thisClass, selfPointer: selfPointer)
        }
        """,
      ]
    )
  }

  @Test
  func returnsGenericValueFuncJava() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static MyID<java.lang.String> makeStringID(java.lang.String value, SwiftArena swiftArena) {
          org.swift.swiftkit.core._OutSwiftGenericInstance result = new org.swift.swiftkit.core._OutSwiftGenericInstance();
          SwiftModule.$makeStringID(value, result);
          return MyID.<java.lang.String>wrapMemoryAddressUnsafe(result.selfPointer, result.selfTypePointer, swiftArena);
        }
        """,
        """
        private static native void $makeStringID(java.lang.String value, org.swift.swiftkit.core._OutSwiftGenericInstance resultOut);
        """,
        """
        public static long takeIntID(MyID<java.lang.Long> value) {
          return SwiftModule.$takeIntID(value.$memoryAddress());
        }
        """,
        """
        private static native long $takeIntID(long value);
        """,
      ]
    )
  }

  @Test
  func returnsGenericValueFuncSwift() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024makeStringID__Ljava_lang_String_2Lorg_swift_swiftkit_core__1OutSwiftGenericInstance_2")
        public func Java_com_example_swift_SwiftModule__00024makeStringID__Ljava_lang_String_2Lorg_swift_swiftkit_core__1OutSwiftGenericInstance_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jstring?, resultOut: jobject?) {
          let result$ = UnsafeMutablePointer<MyID<String>>.allocate(capacity: 1)
          result$.initialize(to: SwiftModule.makeStringID(String(fromJNI: value, in: environment)))
          let resultBits$ = Int(bitPattern: result$)
          do {
            environment.interface.SetLongField(environment, resultOut, _JNIMethodIDCache._OutSwiftGenericInstance.selfPointer, resultBits$.getJNIValue(in: environment))
            let metadataPointer = unsafeBitCast(MyID<String>.self, to: UnsafeRawPointer.self)
            let metadataPointerBits$ = Int(bitPattern: metadataPointer)
            environment.interface.SetLongField(environment, resultOut, _JNIMethodIDCache._OutSwiftGenericInstance.selfTypePointer, metadataPointerBits$.getJNIValue(in: environment))
          }
          return
        }
        """,
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024takeIntID__J")
        public func Java_com_example_swift_SwiftModule__00024takeIntID__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) -> jlong {
          assert(value != 0, "value memory address was null")
          let valueBits$ = Int(fromJNI: value, in: environment)
          let value$ = UnsafeMutablePointer<MyID<Int>>(bitPattern: valueBits$)
          guard let value$ else {
            fatalError("value memory address was null in call to \\(#function)!")
          }
          return SwiftModule.takeIntID(value$.pointee).getJNILocalRefValue(in: environment)
        }
        """,
      ]
    )
  }
}
