//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaKit
import JavaKitNetwork
import JavaKitVM
import JavaRuntime
import Testing

@MainActor
let jvm = try! JavaVirtualMachine(vmOptions: [])

@Suite
@MainActor
struct BasicRuntimeTests {
  @Test("Object management", .disabled(if: isLinux, "Attempts to refcount a null pointer on Linux"))
  func javaObjectManagement() throws {
    let sneakyJavaThis: jobject
    do {
      let object = JavaObject(environment: jvm.environment)
      #expect(object.toString().starts(with: "java.lang.Object"))

      // Make sure this object was promoted to a global reference.
      #expect(object.javaEnvironment.pointee?.pointee.GetObjectRefType(object.javaEnvironment, object.javaThis) == JNIGlobalRefType)

      // Keep track of the Java object.
      sneakyJavaThis = object.javaThis
    }

    // The reference should now be invalid, because we've deleted the
    // global reference.
    #expect(jvm.environment.pointee?.pointee.GetObjectRefType(jvm.environment, sneakyJavaThis) == JNIInvalidRefType)

    // 'super' and 'as' don't require allocating a new holder.
    let url = try URL("http://swift.org", environment: jvm.environment)
    let superURL = url.super
    #expect(url.javaHolder === superURL.javaHolder)
    let urlAgain = superURL.as(URL.self)!
    #expect(url.javaHolder === urlAgain.javaHolder)
  }

  @Test("Java exceptions", .disabled(if: isLinux, "Attempts to refcount a null pointer on Linux"))
  func javaExceptionsInSwift() throws {
    do {
      _ = try URL("bad url", environment: jvm.environment)
    } catch {
      #expect(String(describing: error) == "no protocol: bad url")
    }
  }

  @Test("Static methods")
  func staticMethods() {
    let urlConnectionClass = JavaClass<URLConnection>(
      javaThis: URLConnection.getJNIClass(in: jvm.environment)!,
      environment: jvm.environment
    )

    #expect(urlConnectionClass.getDefaultAllowUserInteraction() == false)
  }
}

/// Whether we're running on Linux.
var isLinux: Bool {
  #if os(Linux)
  return true
  #else
  return false
  #endif
}
