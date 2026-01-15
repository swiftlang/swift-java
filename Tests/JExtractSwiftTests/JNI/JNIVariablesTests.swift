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
struct JNIVariablesTests {
  let membersSource =
    """
    public class MyClass {
      public let someByte: UInt8
      public let constant: Int64
      public var mutable: Int64
      public var computed: Int64 {
        return 0
      }
      public var computedThrowing: Int64 {
        get throws { return 0 }
      }
      public var getterAndSetter: Int64 {
        get { return 0 }
        set { }
      }
      public var someBoolean: Bool
      public var isBoolean: Bool
    }
    """

  @Test
  func constant_javaBindings() throws {
    try assertOutput(input: membersSource, .jni, .java, expectedChunks: [
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public let constant: Int64
       * }
       */
       public long getConstant() {
         return MyClass.$getConstant(this.$memoryAddress());
       }
      """,
      """
      private static native long $getConstant(long self);
      """
    ])
  }

  @Test
  func constant_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024getConstant__J")
        public func Java_com_example_swift_MyClass__00024getConstant__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jlong {
          ...
          return self$.pointee.constant.getJNIValue(in: environment)
        }
        """
      ]
    )
  }

  @Test
  func mutable_javaBindings() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .java,
      detectChunkByInitialLines: 8,
      expectedChunks: [
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public var mutable: Int64
       * }
       */
       public long getMutable() {
         return MyClass.$getMutable(this.$memoryAddress());
       }
      """,
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public var mutable: Int64
       * }
       */
       public void setMutable(long newValue) {
         MyClass.$setMutable(newValue, this.$memoryAddress());
       }
      """,
      """
      private static native long $getMutable(long self);
      """,
      """
      private static native void $setMutable(long newValue, long self);
      """
      ]
    )
  }

  @Test
  func mutable_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024getMutable__J")
        public func Java_com_example_swift_MyClass__00024getMutable__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jlong {
          assert(self != 0, "self memory address was null")
          ...
          let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$)
          guard let self$ else {
            fatalError("self memory address was null in call to \\(#function)!")
          }
          ...
          return self$.pointee.mutable.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyClass__00024setMutable__JJ")
        public func Java_com_example_swift_MyClass__00024setMutable__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, self: jlong) {
          assert(self != 0, "self memory address was null")
          ...
          self$.pointee.mutable = Int64(fromJNI: newValue, in: environment)
        }
        """
      ]
    )
  }

  @Test
  func computed_javaBindings() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .java,
      detectChunkByInitialLines: 8,
      expectedChunks: [
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public var computed: Int64
       * }
       */
       public long getComputed() {
         return MyClass.$getComputed(this.$memoryAddress());
       }
      """,
      """
      private static native long $getComputed(long self);
      """,
      ]
    )
  }

  @Test
  func computed_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024getComputed__J")
        public func Java_com_example_swift_MyClass__00024getComputed__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jlong {
          ...
          return self$.pointee.computed.getJNIValue(in: environment)
        }
        """,
      ]
    )
  }

  @Test
  func computedThrowing_javaBindings() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .java,
      detectChunkByInitialLines: 8,
      expectedChunks: [
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public var computedThrowing: Int64
       * }
       */
       public long getComputedThrowing() throws Exception {
         return MyClass.$getComputedThrowing(this.$memoryAddress());
       }
      """,
      """
      private static native long $getComputedThrowing(long self);
      """,
      ]
    )
  }

  @Test
  func computedThrowing_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024getComputedThrowing__J")
        public func Java_com_example_swift_MyClass__00024getComputedThrowing__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jlong {
          ...
          do {
            return try self$.pointee.computedThrowing.getJNIValue(in: environment)
          } catch {
            environment.throwAsException(error)
            return Int64.jniPlaceholderValue
          }
        }
        """,
      ]
    )
  }

  @Test
  func getterAndSetter_javaBindings() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .java,
      detectChunkByInitialLines: 8,
      expectedChunks: [
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public var getterAndSetter: Int64
       * }
       */
       public long getGetterAndSetter() {
         return MyClass.$getGetterAndSetter(this.$memoryAddress());
       }
      """,
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public var getterAndSetter: Int64
       * }
       */
       public void setGetterAndSetter(long newValue) {
         MyClass.$setGetterAndSetter(newValue, this.$memoryAddress());
       }
      """,
      """
      private static native long $getGetterAndSetter(long self);
      """,
      """
      private static native void $setGetterAndSetter(long newValue, long self);
      """
      ]
    )
  }

  @Test
  func getterAndSetter_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024getGetterAndSetter__J")
        public func Java_com_example_swift_MyClass__00024getGetterAndSetter__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jlong {
          ...
          return self$.pointee.getterAndSetter.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyClass__00024setGetterAndSetter__JJ")
        public func Java_com_example_swift_MyClass__00024setGetterAndSetter__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, self: jlong) {
          ...
          self$.pointee.getterAndSetter = Int64(fromJNI: newValue, in: environment)
        }
        """
      ]
    )
  }

  @Test
  func someBoolean_javaBindings() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .java,
      detectChunkByInitialLines: 8,
      expectedChunks: [
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public var someBoolean: Bool
       * }
       */
       public boolean isSomeBoolean() {
        return MyClass.$isSomeBoolean(this.$memoryAddress());
       }
      """,
      """
      /**
        * Downcall to Swift:
        * {@snippet lang=swift :
        * public var someBoolean: Bool
        * }
        */
        public void setSomeBoolean(boolean newValue) {
          MyClass.$setSomeBoolean(newValue, this.$memoryAddress());
        }
      """,
      """
      private static native boolean $isSomeBoolean(long self);
      """,
      """
      private static native void $setSomeBoolean(boolean newValue, long self);
      """
      ]
    )
  }

  @Test
  func someBoolean_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024isSomeBoolean__J")
        public func Java_com_example_swift_MyClass__00024isSomeBoolean__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jboolean {
          ...
          return self$.pointee.someBoolean.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyClass__00024setSomeBoolean__ZJ")
        public func Java_com_example_swift_MyClass__00024setSomeBoolean__ZJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jboolean, self: jlong) {
          ...
          self$.pointee.someBoolean = Bool(fromJNI: newValue, in: environment)
        }
        """
      ]
    )
  }

  @Test
  func isBoolean_javaBindings() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .java,
      detectChunkByInitialLines: 8,
      expectedChunks: [
      """
      /**
      * Downcall to Swift:
      * {@snippet lang=swift :
      * public var isBoolean: Bool
      * }
      */
      public boolean isBoolean() {
        return MyClass.$isBoolean(this.$memoryAddress());
      }
      """,
      """
      /**
      * Downcall to Swift:
      * {@snippet lang=swift :
      * public var isBoolean: Bool
      * }
      */
      public void setBoolean(boolean newValue) {
        MyClass.$setBoolean(newValue, this.$memoryAddress());
      }
      """,
      """
      private static native boolean $isBoolean(long self);
      """,
      """
      private static native void $setBoolean(boolean newValue, long self);
      """
      ]
    )
  }

  @Test
  func isBoolean_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024isBoolean__J")
        public func Java_com_example_swift_MyClass__00024isBoolean__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jboolean {
          ...
          return self$.pointee.isBoolean.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyClass__00024setBoolean__ZJ")
        public func Java_com_example_swift_MyClass__00024setBoolean__ZJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jboolean, self: jlong) {
          ...
          self$.pointee.isBoolean = Bool(fromJNI: newValue, in: environment)
        }
        """
      ]
    )
  }
}
