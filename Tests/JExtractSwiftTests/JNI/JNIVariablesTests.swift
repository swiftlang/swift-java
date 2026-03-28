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
    try assertOutput(
      input: membersSource,
      .jni,
      .java,
      expectedChunks: [
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
        private static native long $getConstant(long selfPointer);
        """,
      ]
    )
  }

  @Test
  func constant_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 4,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024getConstant__J")
        public func Java_com_example_swift_MyClass__00024getConstant__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          ...
          return selfPointer$.pointee.constant.getJNILocalRefValue(in: environment)
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
        private static native long $getMutable(long selfPointer);
        """,
        """
        private static native void $setMutable(long newValue, long selfPointer);
        """,
      ]
    )
  }

  @Test
  func mutable_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 4,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024getMutable__J")
        public func Java_com_example_swift_MyClass__00024getMutable__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          assert(selfPointer != 0, "selfPointer memory address was null")
          ...
          let selfPointer$ = UnsafeMutablePointer<MyClass>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          ...
          return selfPointer$.pointee.mutable.getJNILocalRefValue(in: environment)
        }
        """,
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024setMutable__JJ")
        public func Java_com_example_swift_MyClass__00024setMutable__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, selfPointer: jlong) {
          assert(selfPointer != 0, "selfPointer memory address was null")
          ...
          selfPointer$.pointee.mutable = Int64(fromJNI: newValue, in: environment)
        }
        """,
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
      detectChunkByInitialLines: 4,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024getComputed__J")
        public func Java_com_example_swift_MyClass__00024getComputed__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          ...
          return selfPointer$.pointee.computed.getJNILocalRefValue(in: environment)
        }
        """
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
      detectChunkByInitialLines: 4,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024getComputedThrowing__J")
        public func Java_com_example_swift_MyClass__00024getComputedThrowing__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          ...
          do {
            return try selfPointer$.pointee.computedThrowing.getJNILocalRefValue(in: environment)
          } catch {
            environment.throwAsException(error)
            return Int64.jniPlaceholderValue
          }
        }
        """
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
        private static native long $getGetterAndSetter(long selfPointer);
        """,
        """
        private static native void $setGetterAndSetter(long newValue, long selfPointer);
        """,
      ]
    )
  }

  @Test
  func getterAndSetter_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 4,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024getGetterAndSetter__J")
        public func Java_com_example_swift_MyClass__00024getGetterAndSetter__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          ...
          return selfPointer$.pointee.getterAndSetter.getJNILocalRefValue(in: environment)
        }
        """,
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024setGetterAndSetter__JJ")
        public func Java_com_example_swift_MyClass__00024setGetterAndSetter__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, selfPointer: jlong) {
          ...
          selfPointer$.pointee.getterAndSetter = Int64(fromJNI: newValue, in: environment)
        }
        """,
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
        private static native boolean $isSomeBoolean(long selfPointer);
        """,
        """
        private static native void $setSomeBoolean(boolean newValue, long selfPointer);
        """,
      ]
    )
  }

  @Test
  func someBoolean_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 4,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024isSomeBoolean__J")
        public func Java_com_example_swift_MyClass__00024isSomeBoolean__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jboolean {
          ...
          return selfPointer$.pointee.someBoolean.getJNILocalRefValue(in: environment)
        }
        """,
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024setSomeBoolean__ZJ")
        public func Java_com_example_swift_MyClass__00024setSomeBoolean__ZJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jboolean, selfPointer: jlong) {
          ...
          selfPointer$.pointee.someBoolean = Bool(fromJNI: newValue, in: environment)
        }
        """,
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
        private static native boolean $isBoolean(long selfPointer);
        """,
        """
        private static native void $setBoolean(boolean newValue, long selfPointer);
        """,
      ]
    )
  }

  @Test
  func isBoolean_swiftThunks() throws {
    try assertOutput(
      input: membersSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 4,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024isBoolean__J")
        public func Java_com_example_swift_MyClass__00024isBoolean__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jboolean {
          ...
          return selfPointer$.pointee.isBoolean.getJNILocalRefValue(in: environment)
        }
        """,
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_MyClass__00024setBoolean__ZJ")
        public func Java_com_example_swift_MyClass__00024setBoolean__ZJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jboolean, selfPointer: jlong) {
          ...
          selfPointer$.pointee.isBoolean = Bool(fromJNI: newValue, in: environment)
        }
        """,
      ]
    )
  }
}
