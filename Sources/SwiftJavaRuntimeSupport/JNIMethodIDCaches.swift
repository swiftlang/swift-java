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

import SwiftJava

extension _JNIMethodIDCache {
  public enum CompletableFuture {
    private static let completeMethod = Method(
      name: "complete",
      signature: "(Ljava/lang/Object;)Z"
    )

    private static let completeExceptionallyMethod = Method(
      name: "completeExceptionally",
      signature: "(Ljava/lang/Throwable;)Z"
    )

    private static let cache = _JNIMethodIDCache(
      className: "java/util/concurrent/CompletableFuture",
      methods: [completeMethod, completeExceptionallyMethod]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    /// CompletableFuture<T>.complete(T)
    public static var complete: jmethodID {
      cache.methods[completeMethod]!
    }

    /// CompletableFuture<T>.completeExceptionally(Throwable)
    public static var completeExceptionally: jmethodID {
      cache.methods[completeExceptionallyMethod]!
    }
  }

  public enum SimpleCompletableFuture {
    private static let completeMethod = Method(
      name: "complete",
      signature: "(Ljava/lang/Object;)Z"
    )

    private static let completeExceptionallyMethod = Method(
      name: "completeExceptionally",
      signature: "(Ljava/lang/Throwable;)Z"
    )

    private static let cache = _JNIMethodIDCache(
      className: "org/swift/swiftkit/core/SimpleCompletableFuture",
      methods: [completeMethod, completeExceptionallyMethod]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var complete: jmethodID {
      cache.methods[completeMethod]!
    }

    public static var completeExceptionally: jmethodID {
      cache.methods[completeExceptionallyMethod]!
    }
  }

  public enum Exception {
    private static let messageConstructor = Method(name: "<init>", signature: "(Ljava/lang/String;)V")

    private static let cache = _JNIMethodIDCache(
      className: "java/lang/Exception",
      methods: [messageConstructor]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var constructWithMessage: jmethodID {
      cache.methods[messageConstructor]!
    }
  }

  public enum JNISwiftInstance {
    private static let memoryAddressMethod = Method(
      name: "$memoryAddress",
      signature: "()J"
    )

    private static let typeMetadataAddressMethod = Method(
      name: "$typeMetadataAddress",
      signature: "()J"
    )

    private static let cache = _JNIMethodIDCache(
      className: "org/swift/swiftkit/core/JNISwiftInstance",
      methods: [memoryAddressMethod, typeMetadataAddressMethod]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var memoryAddress: jmethodID {
      cache.methods[memoryAddressMethod]!
    }

    public static var typeMetadataAddress: jmethodID {
      cache.methods[typeMetadataAddressMethod]!
    }
  }

  public enum SwiftDictionaryMap {
    private static let wrapMemoryAddressUnsafeMethod = Method(
      name: "wrapMemoryAddressUnsafe",
      signature: "(JLorg/swift/swiftkit/core/SwiftArena;)Lorg/swift/swiftkit/core/collections/SwiftDictionaryMap;",
      isStatic: true
    )

    private static let cache = _JNIMethodIDCache(
      className: "org/swift/swiftkit/core/collections/SwiftDictionaryMap",
      methods: [wrapMemoryAddressUnsafeMethod]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var wrapMemoryAddressUnsafe: jmethodID {
      cache.methods[wrapMemoryAddressUnsafeMethod]!
    }
  }

  public enum SwiftSet {
    private static let wrapMemoryAddressUnsafeMethod = Method(
      name: "wrapMemoryAddressUnsafe",
      signature: "(JLorg/swift/swiftkit/core/SwiftArena;)Lorg/swift/swiftkit/core/collections/SwiftSet;",
      isStatic: true
    )

    private static let cache = _JNIMethodIDCache(
      className: "org/swift/swiftkit/core/collections/SwiftSet",
      methods: [wrapMemoryAddressUnsafeMethod]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var wrapMemoryAddressUnsafe: jmethodID {
      cache.methods[wrapMemoryAddressUnsafeMethod]!
    }
  }

  public enum JavaOptional {
    private static let emptyMethod = Method(
      name: "empty",
      signature: "()Ljava/util/Optional;",
      isStatic: true
    )

    private static let ofMethod = Method(
      name: "of",
      signature: "(Ljava/lang/Object;)Ljava/util/Optional;",
      isStatic: true
    )

    private static let isPresentMethod = Method(
      name: "isPresent",
      signature: "()Z"
    )

    private static let getMethod = Method(
      name: "get",
      signature: "()Ljava/lang/Object;"
    )

    private static let cache = _JNIMethodIDCache(
      className: "java/util/Optional",
      methods: [emptyMethod, ofMethod, isPresentMethod, getMethod]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var empty: jmethodID {
      cache.methods[emptyMethod]!
    }

    public static var of: jmethodID {
      cache.methods[ofMethod]!
    }

    public static var isPresent: jmethodID {
      cache.methods[isPresentMethod]!
    }

    public static var get: jmethodID {
      cache.methods[getMethod]!
    }
  }

  public enum _OutSwiftGenericInstance {
    private static let selfPointerField = Field(
      name: "selfPointer",
      signature: "J"
    )

    private static let selfTypePointerField = Field(
      name: "selfTypePointer",
      signature: "J"
    )

    private static let cache = _JNIMethodIDCache(
      className: "org/swift/swiftkit/core/_OutSwiftGenericInstance",
      fields: [selfPointerField, selfTypePointerField]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var selfPointer: jfieldID {
      cache.fields[selfPointerField]!
    }

    public static var selfTypePointer: jfieldID {
      cache.fields[selfTypePointerField]!
    }
  }
}
