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
      public let isBoolean: Bool
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
         long self$ = this.$memoryAddress();
         return MyClass.$getConstant(self$);
       }
      """,
      """
      private static native long $getConstant(long selfPointer);
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
        func Java_com_example_swift_MyClass__00024getConstant__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }
          let result = self$.pointee.constant
          return result.getJNIValue(in: environment)
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
         long self$ = this.$memoryAddress();
         return MyClass.$getMutable(self$);
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
         long self$ = this.$memoryAddress();
         MyClass.$setMutable(newValue, self$);
       }
      """,
      """
      private static native long $getMutable(long selfPointer);
      """,
      """
      private static native void $setMutable(long newValue, long selfPointer);
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
        func Java_com_example_swift_MyClass__00024getMutable__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }
          let result = self$.pointee.mutable
          return result.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyClass__00024setMutable__JJ")
        func Java_com_example_swift_MyClass__00024setMutable__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, selfPointer: jlong) {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }
          self$.pointee.mutable = Int64(fromJNI: newValue, in: environment!)
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
         long self$ = this.$memoryAddress();
         return MyClass.$getComputed(self$);
       }
      """,
      """
      private static native long $getComputed(long selfPointer);
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
        func Java_com_example_swift_MyClass__00024getComputed__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }

          let result = self$.pointee.computed
          return result.getJNIValue(in: environment)
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
         long self$ = this.$memoryAddress();
         return MyClass.$getComputedThrowing(self$);
       }
      """,
      """
      private static native long $getComputedThrowing(long selfPointer);
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
        func Java_com_example_swift_MyClass__00024getComputedThrowing__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }

          do {
            let result = try self$.pointee.computedThrowing
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
         long self$ = this.$memoryAddress();
         return MyClass.$getGetterAndSetter(self$);
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
         long self$ = this.$memoryAddress();
         MyClass.$setGetterAndSetter(newValue, self$);
       }
      """,
      """
      private static native long $getGetterAndSetter(long selfPointer);
      """,
      """
      private static native void $setGetterAndSetter(long newValue, long selfPointer);
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
        func Java_com_example_swift_MyClass__00024getGetterAndSetter__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }

          let result = self$.pointee.getterAndSetter
          return result.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyClass__00024setGetterAndSetter__JJ")
        func Java_com_example_swift_MyClass__00024setGetterAndSetter__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, selfPointer: jlong) {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }

          self$.pointee.getterAndSetter = Int64(fromJNI: newValue, in: environment!)
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
        long self$ = this.$memoryAddress();
        return MyClass.$isSomeBoolean(self$);
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
          long self$ = this.$memoryAddress();
          MyClass.$setSomeBoolean(newValue, self$);
        }
      """,
      """
      private static native boolean $isSomeBoolean(long selfPointer);
      """,
      """
      private static native void $setSomeBoolean(boolean newValue, long selfPointer);
      """
      ]
    )
  }

  @Test
  func boolean_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024isSomeBoolean__J")
        func Java_com_example_swift_MyClass__00024isSomeBoolean__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jboolean {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }
          let result = self$.pointee.someBoolean
          return result.getJNIValue(in: environment)
        }
        """,
        """
        @_cdecl("Java_com_example_swift_MyClass__00024setSomeBoolean__ZJ")
        func Java_com_example_swift_MyClass__00024setSomeBoolean__ZJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jboolean, selfPointer: jlong) {
          guard let env$ = environment else {
            fatalError("Missing JNIEnv in downcall to \\(#function)")
          }
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
          guard let self$ = UnsafeMutablePointer<MyClass>(bitPattern: selfBits$) else {
            fatalError("self memory address was null in call to \\(#function)!")
          }
          self$.pointee.someBoolean = Bool(fromJNI: newValue, in: environment!)
        }
        """
      ]
    )
  }
}
