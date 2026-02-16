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
        private final long selfTypePointer;
        """,
        """
        public java.lang.String getDescription() {
          return MyID.$getDescription(this.$memoryAddress(), this.$typeMetadataAddress());
        }
        private static native java.lang.String $getDescription(long self, long selfType);
        """,
        """
        public String toString() {
          return $toString(this.$memoryAddress(), this.$typeMetadataAddress());
        }
        private static native java.lang.String $toString(long selfPointer, long selfType);
        """,
        """
        @Override
        public long $typeMetadataAddress() {
          return this.selfTypePointer;
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
          static func _get_description(selfBits$: Int) -> String
          static func _toString(selfBits$: Int) -> String
          static func _toDebugString(selfBits$: Int) -> String
        }
        """,
        """
        extension MyID: _SwiftModule_MyID_opener {
          static func _get_description(selfBits$: Int) -> String {
            let self$ = UnsafeMutablePointer<Self>(bitPattern: selfBits$)
            guard let self$ else {
              fatalError("self memory address was null in call to \\(#function)!")
            }
            return self$.pointee.description
          }
          static func _toString(selfBits$: Int) -> String {
            let self$ = UnsafeMutablePointer<Self>(bitPattern: selfBits$)
            guard let self$ else {
              fatalError("self memory address was null in call to \\(#function)!")
            }
            return String(describing: self$.pointee)
          }
          static func _toDebugString(selfBits$: Int) -> String {
            let self$ = UnsafeMutablePointer<Self>(bitPattern: selfBits$)
            guard let self$ else {
              fatalError("self memory address was null in call to \\(#function)!")
            }
            return String(reflecting: self$.pointee)
          }
        } 
        """,
        """
        @_cdecl("Java_com_example_swift_MyID__00024getDescription__J")
        public func Java_com_example_swift_MyID__00024getDescription__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong, selfType: jlong) -> jstring? {
          assert(self != 0, "self memory address was null")
          let selfBits$ = Int(Int64(fromJNI: self, in: environment))
          guard let selfTypeMetadataPointer$ = UnsafeRawPointer(bitPattern: Int(Int64(fromJNI: selfType, in: environment))) else {
            fatalError("selfType memory address was null")
          }
          let erasedSelfType$: Any.Type = unsafeBitCast(selfTypeMetadataPointer$, to: Any.Type.self)
          let openerType = erasedSelfType$ as! (any _SwiftModule_MyID_opener.Type)
          return openerType._get_description(selfBits$: selfBits$).getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyID__00024toString__J")
        public func Java_com_example_swift_MyID__00024toString__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong, selfType: jlong) -> jstring? {
          assert(self != 0, "self memory address was null")
          let selfBits$ = Int(Int64(fromJNI: self, in: environment))
          guard let selfTypeMetadataPointer$ = UnsafeRawPointer(bitPattern: Int(Int64(fromJNI: selfType, in: environment))) else {
            fatalError("selfType memory address was null")
          }
          let erasedSelfType$: Any.Type = unsafeBitCast(selfTypeMetadataPointer$, to: Any.Type.self)
          let openerType = erasedSelfType$ as! (any _SwiftModule_MyID_opener.Type)
          return openerType._toString(selfBits$: selfBits$).getJNIValue(in: environment)
        }
        """,
      ]
    )
  }
}
