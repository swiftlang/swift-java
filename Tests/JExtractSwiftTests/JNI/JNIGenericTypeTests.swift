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
        public final class MyID implements JNISwiftInstance {
        """,
        """
        private MyID(long selfPointer, long selfTypePointer, SwiftArena swiftArena) {
        """,
        """
        public static MyID wrapMemoryAddressUnsafe(long selfPointer, long selfTypePointer, SwiftArena swiftArena) {
          return new MyID(selfPointer, selfTypePointer, swiftArena);
        }

        public static MyID wrapMemoryAddressUnsafe(long selfPointer, long selfTypePointer) {
          return new MyID(selfPointer, selfTypePointer, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA);
        }
        """,
        """
        private final long selfTypePointer;
        """,
        """
        public java.lang.String getDescription() {
          return MyID.$getDescription(this.$memoryAddress(), this.$typeMetadataAddress());
        }
        private static native java.lang.String $getDescription(long self, long selfType);
        """,
        """
        @Override
        public long $typeMetadataAddress() {
          return this.selfTypePointer;
        }
        """,
        """
        private static native void $destroy(long selfPointer, long selfType);
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
              MyID.$destroy(self$, selfType$);
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
          static func _get_description(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jstring?
          ...
        }
        """,
        #"""
        extension MyID: _SwiftModule_MyID_opener {
          static func _get_description(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jstring? {
            assert(self != 0, "self memory address was null")
            let selfBits$ = Int(Int64(fromJNI: self, in: environment))
            let self$ = UnsafeMutablePointer<MyID>(bitPattern: selfBits$)
            guard let self$ else {
             fatalError("self memory address was null in call to \(#function)!")
            }
            return self$.pointee.description.getJNIValue(in: environment)
          }
          ...
        }
        """#,
        """
        @_cdecl("Java_com_example_swift_MyID__00024getDescription__JJ")
        public func Java_com_example_swift_MyID__00024getDescription__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong, selfType: jlong) -> jstring? {
          let selfTypeBits$ = Int(Int64(fromJNI: selfType, in: environment))
          guard let selfType$ = UnsafeRawPointer(bitPattern: selfTypeBits$) else {
            fatalError("selfType metadata address was null")
          }
          let openerType = unsafeBitCast(selfType$, to: Any.Type.self) as! (any _SwiftModule_MyID_opener.Type)
          return openerType._get_description(environment: environment, thisClass: thisClass, self: self)
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
        public static MyID makeStringID(java.lang.String value, SwiftArena swiftArena$) {
          org.swift.swiftkit.core.OutSwiftGenericInstance instance = new org.swift.swiftkit.core.OutSwiftGenericInstance();
          SwiftModule.$makeStringID(value, instance);
          return MyID.wrapMemoryAddressUnsafe(instance.selfPointer, instance.selfTypePointer, swiftArena$);
        }
        """,
        """
        private static native void $makeStringID(java.lang.String value, org.swift.swiftkit.core.OutSwiftGenericInstance out);
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
        @_cdecl("Java_com_example_swift_SwiftModule__00024makeStringID__Ljava_lang_String_2Lorg_swift_swiftkit_core_OutSwiftGenericInstance_2")
        public func Java_com_example_swift_SwiftModule__00024makeStringID__Ljava_lang_String_2Lorg_swift_swiftkit_core_OutSwiftGenericInstance_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jstring?, out: jobject?) {
          let result$ = UnsafeMutablePointer<MyID<String>>.allocate(capacity: 1)
          result$.initialize(to: SwiftModule.makeStringID(String(fromJNI: value, in: environment)))
          let resultBits$ = Int64(Int(bitPattern: result$))
          environment.interface.SetLongField(environment, out, _JNIMethodIDCache.OutSwiftGenericInstance.selfPointer, resultBits$.getJNIValue(in: environment))
          let metadataPointer = unsafeBitCast(MyID<String>.self, to: UnsafeRawPointer.self)
          let metadataPointerBits$ = Int64(Int(bitPattern: metadataPointer))
          environment.interface.SetLongField(environment, out, _JNIMethodIDCache.OutSwiftGenericInstance.selfTypePointer, metadataPointerBits$.getJNIValue(in: environment))
          return
        }
        """
      ]
    )
  }
}
