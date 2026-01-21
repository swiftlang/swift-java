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
struct JNIClosureTests {
  let source =
    """
    public func emptyClosure(closure: () -> ()) {}
    public func closureWithArgumentsAndReturn(closure: (Int64, Bool) -> Int64) {}
    """

  @Test
  func emptyClosure_javaBindings() throws {
    try assertOutput(input: source, .jni, .java, expectedChunks: [
      """
      public static class emptyClosure {
        @FunctionalInterface
        public interface closure {
          void apply();
        }
      }
      """,
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public func emptyClosure(closure: () -> ())
       * }
       */
      public static void emptyClosure(com.example.swift.SwiftModule.emptyClosure.closure closure) {
        SwiftModule.$emptyClosure(closure);
      }
      """,
      """
      private static native void $emptyClosure(com.example.swift.SwiftModule.emptyClosure.closure closure);
      """
    ])
  }

  @Test
  func emptyClosure_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024emptyClosure__Lcom_example_swift_SwiftModule_00024emptyClosure_00024closure_2")
        public func Java_com_example_swift_SwiftModule__00024emptyClosure__Lcom_example_swift_SwiftModule_00024emptyClosure_00024closure_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.emptyClosure(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "apply", "()V")!
            let arguments$: [jvalue] = []
            environment.interface.CallVoidMethodA(environment, closure, methodID$, arguments$)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureWithArgumentsAndReturn_javaBindings() throws {
    try assertOutput(input: source, .jni, .java, expectedChunks: [
      """
      public static class closureWithArgumentsAndReturn {
        @FunctionalInterface
        public interface closure {
          long apply(long _0, boolean _1);
        }
      }
      """,
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public func closureWithArgumentsAndReturn(closure: (Int64, Bool) -> Int64)
       * }
       */
      public static void closureWithArgumentsAndReturn(com.example.swift.SwiftModule.closureWithArgumentsAndReturn.closure closure) {
        SwiftModule.$closureWithArgumentsAndReturn(closure);
      }
      """,
      """
      private static native void $closureWithArgumentsAndReturn(com.example.swift.SwiftModule.closureWithArgumentsAndReturn.closure closure);
      """
    ])
  }

  @Test
  func closureWithArgumentsAndReturn_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureWithArgumentsAndReturn__Lcom_example_swift_SwiftModule_00024closureWithArgumentsAndReturn_00024closure_2")
        public func Java_com_example_swift_SwiftModule__00024closureWithArgumentsAndReturn__Lcom_example_swift_SwiftModule_00024closureWithArgumentsAndReturn_00024closure_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureWithArgumentsAndReturn(closure: { _0, _1 in
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "apply", "(JZ)J")!
            let arguments$: [jvalue] = [_0.getJValue(in: environment), _1.getJValue(in: environment)]
            return Int64(fromJNI: environment.interface.CallLongMethodA(environment, closure, methodID$, arguments$), in: environment)
          }
          )
        }
        """
      ]
    )
  }
}
