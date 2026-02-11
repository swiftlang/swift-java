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
import SwiftJavaConfigurationShared
import Testing

@Suite
struct JNIAsyncTests {

  @Test("Import: async -> Void (Java, CompletableFuture)")
  func completableFuture_asyncVoid_java() throws {
    try assertOutput(
      input: "public func asyncVoid() async",
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func asyncVoid() async
         * }
         */
        public static java.util.concurrent.CompletableFuture<java.lang.Void> asyncVoid() {
          java.util.concurrent.CompletableFuture<java.lang.Void> future$ = new java.util.concurrent.CompletableFuture<java.lang.Void>();
          SwiftModule.$asyncVoid(future$);
          return future$.thenApply((futureResult$) -> {
            return futureResult$;
          }
          );
        }
        """,
        """
        private static native void $asyncVoid(java.util.concurrent.CompletableFuture<java.lang.Void> result_future);
        """,
      ]
    )
  }

  @Test("Import: async -> Void (Swift, CompletableFuture)")
  func completableFuture_asyncVoid_swift() throws {
    try assertOutput(
      input: "public func asyncVoid() async",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024asyncVoid__Ljava_util_concurrent_CompletableFuture_2")
        public func Java_com_example_swift_SwiftModule__00024asyncVoid__Ljava_util_concurrent_CompletableFuture_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, result_future: jobject?) {
          let globalFuture = environment.interface.NewGlobalRef(environment, result_future)
          var task: Task<Void, Never>? = nil
          #if swift(>=6.2)
            if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
              task = Task.immediate {
                var environment = environment!
                defer {
                  let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                  deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
                }
                await SwiftModule.asyncVoid()
                environment = try! JavaVirtualMachine.shared().environment()
                _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: nil)])
              }
            }
          #endif
          if task == nil {
            task = Task {
              var environment = try! JavaVirtualMachine.shared().environment()
              defer {
                let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
              }
              await SwiftModule.asyncVoid()
              environment = try! JavaVirtualMachine.shared().environment()
              _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: nil)])
            }
          }
        }
        """
      ]
    )
  }

  @Test("Import: async throws -> Void (Java, CompletableFuture)")
  func completableFuture_asyncThrowsVoid_java() throws {
    try assertOutput(
      input: "public func async() async throws",
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async() async throws
         * }
         */
        public static java.util.concurrent.CompletableFuture<java.lang.Void> async() {
          java.util.concurrent.CompletableFuture<java.lang.Void> future$ = new java.util.concurrent.CompletableFuture<java.lang.Void>();
          SwiftModule.$async(future$);
          return future$.thenApply((futureResult$) -> {
            return futureResult$;
          }
          );
        }
        """,
        """
        private static native void $async(java.util.concurrent.CompletableFuture<java.lang.Void> result_future);
        """,
      ]
    )
  }

  @Test("Import: async throws -> Void (Swift, CompletableFuture)")
  func completableFuture_asyncThrowsVoid_swift() throws {
    try assertOutput(
      input: "public func async() async throws",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__Ljava_util_concurrent_CompletableFuture_2")
        public func Java_com_example_swift_SwiftModule__00024async__Ljava_util_concurrent_CompletableFuture_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, result_future: jobject?) {
          let globalFuture = environment.interface.NewGlobalRef(environment, result_future)
          var task: Task<Void, Never>? = nil
          #if swift(>=6.2)
            if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
              task = Task.immediate {
                var environment = environment!
                defer {
                  let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                  deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
                }
                do {
                  try await SwiftModule.async()
                  environment = try! JavaVirtualMachine.shared().environment()
                  _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: nil)])
                }
                catch {
                  let catchEnvironment = try! JavaVirtualMachine.shared().environment()
                  let exception = catchEnvironment.interface.NewObjectA(catchEnvironment, _JNIMethodIDCache.Exception.class, _JNIMethodIDCache.Exception.constructWithMessage, [String(describing: error).getJValue(in: catchEnvironment)])
                  _ = catchEnvironment.interface.CallBooleanMethodA(catchEnvironment, globalFuture, _JNIMethodIDCache.CompletableFuture.completeExceptionally, [jvalue(l: exception)])
                }
              }
            }
          #endif
          if task == nil {
            task = Task {
              var environment = try! JavaVirtualMachine.shared().environment()
              defer {
                let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
              }
              do {
                try await SwiftModule.async()
                environment = try! JavaVirtualMachine.shared().environment()
                _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: nil)])
              }
              catch {
                let catchEnvironment = try! JavaVirtualMachine.shared().environment()
                let exception = catchEnvironment.interface.NewObjectA(catchEnvironment, _JNIMethodIDCache.Exception.class, _JNIMethodIDCache.Exception.constructWithMessage, [String(describing: error).getJValue(in: catchEnvironment)])
                _ = catchEnvironment.interface.CallBooleanMethodA(catchEnvironment, globalFuture, _JNIMethodIDCache.CompletableFuture.completeExceptionally, [jvalue(l: exception)])
              }
            }
          }
        }
        """
      ]
    )
  }

  @Test("Import: (Int64) async -> Int64 (Java, CompletableFuture)")
  func completableFuture_asyncIntToInt_java() throws {
    try assertOutput(
      input: "public func async(i: Int64) async -> Int64",
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async(i: Int64) async -> Int64
         * }
         */
        public static java.util.concurrent.CompletableFuture<java.lang.Long> async(long i) {
          java.util.concurrent.CompletableFuture<java.lang.Long> future$ = new java.util.concurrent.CompletableFuture<java.lang.Long>();
          SwiftModule.$async(i, future$);
          return future$.thenApply((futureResult$) -> {
            return futureResult$;
          }
          );
        }
        """,
        """
        private static native void $async(long i, java.util.concurrent.CompletableFuture<java.lang.Long> result_future);
        """,
      ]
    )
  }

  @Test("Import: (Int64) async -> Int64 (Swift, CompletableFuture)")
  func completableFuture_asyncIntToInt_swift() throws {
    try assertOutput(
      input: "public func async(i: Int64) async -> Int64",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__JLjava_util_concurrent_CompletableFuture_2")
        public func Java_com_example_swift_SwiftModule__00024async__JLjava_util_concurrent_CompletableFuture_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, i: jlong, result_future: jobject?) {
          let globalFuture = environment.interface.NewGlobalRef(environment, result_future)
          var task: Task<Void, Never>? = nil
          #if swift(>=6.2)
          if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            task = Task.immediate {
              var environment = environment!
              defer {
                let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
              }
              let swiftResult$ = await SwiftModule.async(i: Int64(fromJNI: i, in: environment))
              environment = try! JavaVirtualMachine.shared().environment()
              let boxedResult$ = SwiftJavaRuntimeSupport._JNIBoxedConversions.box(swiftResult$.getJNIValue(in: environment), in: environment)
              _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: boxedResult$)])
            }
          }
          #endif // end of swift(>=6.2)
          if task == nil {
            task = Task {
              var environment = try! JavaVirtualMachine.shared().environment()
              defer {
                let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
              }
              let swiftResult$ = await SwiftModule.async(i: Int64(fromJNI: i, in: environment))
              environment = try! JavaVirtualMachine.shared().environment()
              let boxedResult$ = SwiftJavaRuntimeSupport._JNIBoxedConversions.box(swiftResult$.getJNIValue(in: environment), in: environment)
              _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: boxedResult$)])
            }
          }
          return
        }
        """
      ]
    )
  }

  @Test("Import: (MyClass) async -> MyClass (Java, CompletableFuture)")
  func completableFuture_asyncMyClassToMyClass_java() throws {
    try assertOutput(
      input: """
        class MyClass { }

        public func async(c: MyClass) async -> MyClass
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async(c: MyClass) async -> MyClass
         * }
         */
        public static java.util.concurrent.CompletableFuture<MyClass> async(MyClass c, SwiftArena swiftArena$) {
          java.util.concurrent.CompletableFuture<java.lang.Long> future$ = new java.util.concurrent.CompletableFuture<java.lang.Long>();
          SwiftModule.$async(c.$memoryAddress(), future$);
          return future$.thenApply((futureResult$) -> {
            return MyClass.wrapMemoryAddressUnsafe(futureResult$, swiftArena$);
          }
          );
        }
        """,
        """
        private static native void $async(long c, java.util.concurrent.CompletableFuture<java.lang.Long> result_future);
        """,
      ]
    )
  }

  @Test("Import: (MyClass) async -> MyClass (Swift, CompletableFuture)")
  func completableFuture_asyncMyClassToMyClass_swift() throws {
    try assertOutput(
      input: """
        class MyClass { }

        public func async(c: MyClass) async -> MyClass
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__JLjava_util_concurrent_CompletableFuture_2")
        public func Java_com_example_swift_SwiftModule__00024async__JLjava_util_concurrent_CompletableFuture_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, c: jlong, result_future: jobject?) {
          assert(c != 0, "c memory address was null")
          let cBits$ = Int(Int64(fromJNI: c, in: environment))
          let c$ = UnsafeMutablePointer<MyClass>(bitPattern: cBits$)
          guard let c$ else {
            fatalError("c memory address was null in call to \\(#function)!")
          }
          let globalFuture = environment.interface.NewGlobalRef(environment, result_future)
          var task: Task<Void, Never>? = nil
          #if swift(>=6.2)
            if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
              task = Task.immediate {
                var environment = environment!
                defer {
                  let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                  deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
                }
                let swiftResult$ = await SwiftModule.async(c: c$.pointee)
                environment = try! JavaVirtualMachine.shared().environment()
                let result$ = UnsafeMutablePointer<MyClass>.allocate(capacity: 1)
                result$.initialize(to: swiftResult$)
                let resultBits$ = Int64(Int(bitPattern: result$))
                let boxedResult$ = SwiftJavaRuntimeSupport._JNIBoxedConversions.box(resultBits$.getJNIValue(in: environment), in: environment)
                _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: boxedResult$)])
              }
            }
          #endif
          if task == nil {
            task = Task {
              var environment = try! JavaVirtualMachine.shared().environment()
              defer {
                let deferEnvironment = try! JavaVirtualMachine.shared().environment()
                deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
              }
              let swiftResult$ = await SwiftModule.async(c: c$.pointee)
              environment = try! JavaVirtualMachine.shared().environment()
              let result$ = UnsafeMutablePointer<MyClass>.allocate(capacity: 1)
              result$.initialize(to: swiftResult$)
              let resultBits$ = Int64(Int(bitPattern: result$))
              let boxedResult$ = SwiftJavaRuntimeSupport._JNIBoxedConversions.box(resultBits$.getJNIValue(in: environment), in: environment)
              _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: boxedResult$)])
            }
          }
          return
        }
        """
      ]
    )
  }

  @Test("Import: (String) async -> String (Java, CompletableFuture)")
  func completableFuture_asyncStringToString_java() throws {
    try assertOutput(
      input: """
        public func async(s: String) async -> String
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static java.util.concurrent.CompletableFuture<java.lang.String> async(java.lang.String s) {
          java.util.concurrent.CompletableFuture<java.lang.String> future$ = new java.util.concurrent.CompletableFuture<java.lang.String>();
          SwiftModule.$async(s, future$);
          return future$.thenApply((futureResult$) -> {
            return futureResult$;
          }
          );
        }
        """,
        """
        private static native void $async(java.lang.String s, java.util.concurrent.CompletableFuture<java.lang.String> result_future);
        """,
      ]
    )
  }

  @Test("Import: (String) async -> String (Swift, CompletableFuture)")
  func completableFuture_asyncStringToString_swift() throws {
    try assertOutput(
      input: """
        public func async(s: String) async -> String
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__Ljava_lang_String_2Ljava_util_concurrent_CompletableFuture_2")
        public func Java_com_example_swift_SwiftModule__00024async__Ljava_lang_String_2Ljava_util_concurrent_CompletableFuture_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, s: jstring?, result_future: jobject?) {
          let s = environment.interface.NewGlobalRef(environment, s)
          let globalFuture = environment.interface.NewGlobalRef(environment, result_future)
          ...
          defer {
            let deferEnvironment = try! JavaVirtualMachine.shared().environment()
            deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, globalFuture)
            deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, s)
          }
          ...
          _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.CompletableFuture.complete, [jvalue(l: swiftResult$.getJNIValue(in: environment))])
          ...
        }
        """
      ]
    )
  }

  @Test("Import: (MyClass) async -> MyClass (Java, LegacyFuture)")
  func legacyFuture_asyncMyClassToMyClass_java() throws {
    var config = Configuration()
    config.asyncFuncMode = .legacyFuture

    try assertOutput(
      input: """
        class MyClass { }

        public func async(c: MyClass) async -> MyClass
        """,
      config: config,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static java.util.concurrent.Future<MyClass> async(MyClass c, SwiftArena swiftArena$) {
          org.swift.swiftkit.core.SimpleCompletableFuture<java.lang.Long> future$ = new org.swift.swiftkit.core.SimpleCompletableFuture<java.lang.Long>();
          SwiftModule.$async(c.$memoryAddress(), future$);
          return future$.thenApply((futureResult$) -> {
            return MyClass.wrapMemoryAddressUnsafe(futureResult$, swiftArena$);
          }
          );
        }
        """,
        """
        private static native void $async(long c, org.swift.swiftkit.core.SimpleCompletableFuture<java.lang.Long> result_future);
        """,
      ]
    )
  }

  @Test("Import: (MyClass) async -> MyClass (Swift, LegacyFuture)")
  func legacyFuture_asyncMyClassToMyClass_swift() throws {
    var config = Configuration()
    config.asyncFuncMode = .legacyFuture

    try assertOutput(
      input: """
        class MyClass { }

        public func async(c: MyClass) async -> MyClass
        """,
      config: config,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__JLorg_swift_swiftkit_core_SimpleCompletableFuture_2")
        public func Java_com_example_swift_SwiftModule__00024async__JLorg_swift_swiftkit_core_SimpleCompletableFuture_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, c: jlong, result_future: jobject?) {
          ...
          var task: Task<Void, Never>? = nil
          ...
          _ = environment.interface.CallBooleanMethodA(environment, globalFuture, _JNIMethodIDCache.SimpleCompletableFuture.complete, [jvalue(l: boxedResult$)])
          ...
        }
        """
      ]
    )
  }
}
