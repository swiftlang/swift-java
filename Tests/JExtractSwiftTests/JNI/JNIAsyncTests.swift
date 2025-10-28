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
struct JNIAsyncTests {

  @Test("Import: async -> Void (Java, CompletableFuture)")
  func completableFuture_asyncVoid_java() throws {
    try assertOutput(
      input: "public func asyncVoid() async",
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func asyncVoid() async
         * }
         */
        public static java.util.concurrent.CompletableFuture<Void> asyncVoid() {
          return java.util.concurrent.CompletableFuture.supplyAsync(() -> {
            SwiftModule.$asyncVoid();
            return null;
          }
          );
        }
        """,
        """
        private static native void $asyncVoid();
        """,
      ]
    )
  }

  @Test("Import: async -> Void (Swift, CompletableFuture)")
  func completableFuture_asyncVoid_swift() throws {
    try assertOutput(
      input: "public func asyncVoid() async",
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024asyncVoid__")
        func Java_com_example_swift_SwiftModule__00024asyncVoid__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) {
          let _semaphore$ = _Semaphore(value: 0)
          var swiftResult$: ()!
          if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            Task.immediate {
              swiftResult$ = await SwiftModule.asyncVoid()
              _semaphore$.signal()
            }
          }
          else {
            Task {
              swiftResult$ = await SwiftModule.asyncVoid()
              _semaphore$.signal()
            }
          }
          _semaphore$.wait() 
          swiftResult$
        }
        """
      ]
    )
  }

  @Test("Import: async throws -> Void (Java, CompletableFuture)")
  func completableFuture_asyncThrowsVoid_java() throws {
    try assertOutput(
      input: "public func async() async throws",
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async() async throws
         * }
         */
        public static java.util.concurrent.CompletableFuture<Void> async() {
          return java.util.concurrent.CompletableFuture.supplyAsync(() -> {
            SwiftModule.$async();
            return null;
          }
          );
        }
        """,
        """
        private static native void $async();
        """,
      ]
    )
  }

  @Test("Import: async throws -> Void (Swift, CompletableFuture)")
  func completableFuture_asyncThrowsVoid_swift() throws {
    try assertOutput(
      input: "public func async() async throws",
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__")
        func Java_com_example_swift_SwiftModule__00024async__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) {
          do {
            let _semaphore$ = _Semaphore(value: 0)
            var swiftResult$: Result<(), any Error>!
            if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
              Task.immediate {
                do {
                  swiftResult$ = await Result.success(try SwiftModule.async())
                }
                catch {
                  swiftResult$ = Result.failure(error)
                }
                _semaphore$.signal()
              }
            }
            else {
              Task {
                do {
                  swiftResult$ = await Result.success(try SwiftModule.async())
                }
                catch {
                  swiftResult$ = Result.failure(error)
                }
                _semaphore$.signal()
              }
            }
            _semaphore$.wait() 
            try swiftResult$.get()
          } catch {
            environment.throwAsException(error)
            
          }
        """
      ]
    )
  }

  @Test("Import: (Int64) async -> Int64 (Java, CompletableFuture)")
  func completableFuture_asyncIntToInt_java() throws {
    try assertOutput(
      input: "public func async(i: Int64) async -> Int64",
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async(i: Int64) async -> Int64
         * }
         */
        public static java.util.concurrent.CompletableFuture<Long> async(long i) {
          return java.util.concurrent.CompletableFuture.supplyAsync(() -> {
            return SwiftModule.$async(i);
          }
          );
        }
        """,
        """
        private static native long $async(long i);
        """,
      ]
    )
  }

  @Test("Import: (Int64) async -> Int64 (Swift, CompletableFuture)")
  func completableFuture_asyncIntToInt_swift() throws {
    try assertOutput(
      input: "public func async(i: Int64) async -> Int64",
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__J")
        func Java_com_example_swift_SwiftModule__00024async__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, i: jlong) -> jlong {
          let _semaphore$ = _Semaphore(value: 0)
          var swiftResult$: Int64!
          if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            Task.immediate {
              swiftResult$ = await SwiftModule.async(i: Int64(fromJNI: i, in: environment!))
              _semaphore$.signal()
            }
          }
          else {
            Task {
              swiftResult$ = await SwiftModule.async(i: Int64(fromJNI: i, in: environment!))
              _semaphore$.signal()
            }
          }
          _semaphore$.wait() 
          return swiftResult$.getJNIValue(in: environment!)
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
      .jni, .java,
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
          return java.util.concurrent.CompletableFuture.supplyAsync(() -> {
            return MyClass.wrapMemoryAddressUnsafe(SwiftModule.$async(c.$memoryAddress()), swiftArena$);
          }
          );
        }
        """,
        """
        private static native long $async(long c);
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
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__J")
        func Java_com_example_swift_SwiftModule__00024async__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, c: jlong) -> jlong {
          assert(c != 0, "c memory address was null")
          let cBits$ = Int(Int64(fromJNI: c, in: environment!))
          let c$ = UnsafeMutablePointer<MyClass>(bitPattern: cBits$)
          guard let c$ else {
            fatalError("c memory address was null in call to \\(#function)!")
          }
          let _semaphore$ = _Semaphore(value: 0)
          var swiftResult$: MyClass!
          if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            Task.immediate {
              swiftResult$ = await SwiftModule.async(c: c$.pointee)
              _semaphore$.signal()
            } // render(_:_:) @ JExtractSwiftLib/JNISwift2JavaGenerator+NativeTranslation.swift:873
          } // render(_:_:) @ JExtractSwiftLib/JNISwift2JavaGenerator+NativeTranslation.swift:872
          else {
            Task {
              swiftResult$ = await SwiftModule.async(c: c$.pointee)
              _semaphore$.signal()
            } // render(_:_:) @ JExtractSwiftLib/JNISwift2JavaGenerator+NativeTranslation.swift:878
          } // render(_:_:) @ JExtractSwiftLib/JNISwift2JavaGenerator+NativeTranslation.swift:877
          _semaphore$.wait() 
          let result$ = UnsafeMutablePointer<MyClass>.allocate(capacity: 1)
          result$.initialize(to: swiftResult$)
          let resultBits$ = Int64(Int(bitPattern: result$))
          return resultBits$.getJNIValue(in: environment!)
        }
        """
      ]
    )
  }
}
