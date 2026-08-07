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
struct JNINestedTypesTests {
  let source1 = """
    public class A {
      public class B {
        public func g(c: C) {}

        public struct C {
          public func h(b: B) {}
        }
      }
    }

    public func f(a: A, b: A.B, c: A.B.C) {}
    """

  @Test("Import: class and struct A.B.C (Java)")
  func nestedClassesAndStructs_java() throws {
    try assertOutput(
      input: source1,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public final class A implements JNISwiftInstance {
          ...
          public static final class B implements JNISwiftInstance {
            ...
            public static final class C implements JNISwiftInstance {
              ...
              public void h(A.B b) {
              ...
            }
            ...
            public void g(A.B.C c) {
            ...
          }
          ...
        }
        """,
        """
        public static void f(A a, A.B b, A.B.C c) {
          ...
        }
        ...
        """,
      ]
    )
  }

  @Test("Import: class and struct A.B.C (Swift)")
  func nestedClassesAndStructs_swift() throws {
    try assertOutput(
      input: source1,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_A__00024typeMetadataAddressDowncall__")
        public func Java_com_example_swift_A__00024typeMetadataAddressDowncall__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
          ...
        }
        """,
        """
        @_cdecl("Java_com_example_swift_A_00024B__00024typeMetadataAddressDowncall__")
        public func Java_com_example_swift_A_00024B__00024typeMetadataAddressDowncall__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
          ...
        }
        """,
        """
        @_cdecl("Java_com_example_swift_A_00024B_00024C__00024typeMetadataAddressDowncall__")
        public func Java_com_example_swift_A_00024B_00024C__00024typeMetadataAddressDowncall__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
          ...
        }
        """,
        """
        @_cdecl("Java_com_example_swift_A_00024B_00024C__00024h__JJ")
        public func Java_com_example_swift_A_00024B_00024C__00024h__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, b: jlong, selfPointer: jlong) {
          ...
        }
        """,
      ]
    )
  }

  @Test("Import: shadowed nested type name")
  func shadowedNestedTypeName_java() throws {
    // A nested type whose name shadows a type of the same name in an outer
    // scope must resolve to the innermost declaration.
    try assertOutput(
      input: """
        public struct Outer {
          public enum Kind {
            case alpha
            case beta
          }

          public struct Inner {
            public enum Kind {
              case one
              case two
            }

            public var kind: Kind // Outer.Inner.Kind
          }

          public var kind: Kind // Outer.Kind
          public var inner: Inner
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // The `Inner.kind` property must reference `Outer.Inner.Kind`, not `Outer.Kind`.
        """
        public Outer.Inner.Kind getKind(SwiftArena swiftArena) {
          return Outer.Inner.Kind.wrapMemoryAddressUnsafe(Outer.Inner.$getKind(this.$memoryAddress()), swiftArena);
        """,
        """
        public void setKind(Outer.Inner.Kind newValue) {
          Outer.Inner.$setKind(newValue.$memoryAddress(), this.$memoryAddress());
        """,
        // The outer `kind` must reference `Outer.Kind`.
        """
        public Outer.Kind getKind(SwiftArena swiftArena) {
          return Outer.Kind.wrapMemoryAddressUnsafe(Outer.$getKind(this.$memoryAddress()), swiftArena);
        """,
      ]
    )
  }

  @Test("Import: shadowed nested type name inside #if")
  func shadowedNestedTypeName_ifConfig_java() throws {
    try assertOutput(
      input: """
        public struct Outer {
          #if SOME_FLAG
          public enum Kind {
            case alphaX
          }
          #else
          public enum Kind {
            case alpha
            case beta
          }
          #endif

          public struct Inner {
            #if SOME_FLAG
            public enum Kind {
              case oneX
            }
            #else
            public enum Kind {
              case one
              case two
            }
            #endif

            public var kind: Kind // Outer.Inner.Kind
          }

          public var kind: Kind // Outer.Kind
          public var inner: Inner
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public Outer.Inner.Kind getKind(SwiftArena swiftArena) {
          return Outer.Inner.Kind.wrapMemoryAddressUnsafe(Outer.Inner.$getKind(this.$memoryAddress()), swiftArena);
        """,
        """
        public void setKind(Outer.Inner.Kind newValue) {
          Outer.Inner.$setKind(newValue.$memoryAddress(), this.$memoryAddress());
        """,
      ]
    )
  }

  @Test("Import: shadowed nested type name in deeper nesting")
  func shadowedNestedTypeName_deep_java() throws {
    try assertOutput(
      input: """
        public struct DiscordChannel {
          public struct Kind {
            public init() {}
          }

          public struct Message {
            public struct MessageReference {
              public struct Kind {
                public init() {}
              }
              public var kind: Kind
            }
          }
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // The `MessageReference.kind` property must reference the deeply nested
        // `DiscordChannel.Message.MessageReference.Kind`, not `DiscordChannel.Kind`.
        """
        public DiscordChannel.Message.MessageReference.Kind getKind(SwiftArena swiftArena) {
        """,
        """
        public void setKind(DiscordChannel.Message.MessageReference.Kind newValue) {
        """,
      ]
    )
  }

  @Test("Import: shadowed nested type name declared via extension")
  func shadowedNestedTypeName_extension_java() throws {
    try assertOutput(
      input: """
        public struct Outer {
          public enum Kind {
            case alpha
            case beta
          }
        }

        extension Outer {
          public struct Inner {
            public enum Kind {
              case one
              case two
            }

            public var kind: Kind // Outer.Inner.Kind
          }
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // The `Inner.kind` property must reference `Outer.Inner.Kind`, not `Outer.Kind`.
        """
        public Outer.Inner.Kind getKind(SwiftArena swiftArena) {
          return Outer.Inner.Kind.wrapMemoryAddressUnsafe(Outer.Inner.$getKind(this.$memoryAddress()), swiftArena);
        """,
        """
        public void setKind(Outer.Inner.Kind newValue) {
          Outer.Inner.$setKind(newValue.$memoryAddress(), this.$memoryAddress());
        """,
      ]
    )
  }

  @Test("Import: nested in enum")
  func nestedEnums_java() throws {
    try assertOutput(
      input: """
        public enum MyError {
          case text(TextMessage)

          public struct TextMessage {}
        }

        public func f(text: MyError.TextMessage) {}
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public final class MyError implements JNISwiftInstance {
          ...
          public static final class TextMessage implements JNISwiftInstance {
          ...
          }
          ...
          public static MyError text(MyError.TextMessage arg0, SwiftArena swiftArena) {
          ...
        }
        """,
        """
        public static void f(MyError.TextMessage text) {
          ...
        }
        """,
      ]
    )
  }
}
