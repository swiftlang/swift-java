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
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

@MainActor
let jvm = try! JavaVirtualMachine(vmOptions: [])

@MainActor
class BasicRuntimeTests: XCTestCase {
  func testJavaObjectManagement() throws {
    if isLinux {
      throw XCTSkip("Attempts to refcount a null pointer on Linux")
    }

    let sneakyJavaThis: jobject
    do {
      let object = JavaObject(environment: jvm.environment)
      XCTAssert(object.toString().starts(with: "java.lang.Object"))

      // Make sure this object was promoted to a global reference.
      XCTAssertEqual(object.javaEnvironment.pointee?.pointee.GetObjectRefType(object.javaEnvironment, object.javaThis), JNIGlobalRefType)

      // Keep track of the Java object.
      sneakyJavaThis = object.javaThis
    }

    // The reference should now be invalid, because we've deleted the
    // global reference.
    XCTAssertEqual(jvm.environment.pointee?.pointee.GetObjectRefType(jvm.environment, sneakyJavaThis), JNIInvalidRefType)

    // 'super' and 'as' don't require allocating a new holder.
    let url = try URL("http://swift.org", environment: jvm.environment)
    let superURL = url.super
    XCTAssert(url.javaHolder === superURL.javaHolder)
    let urlAgain = superURL.as(URL.self)!
    XCTAssert(url.javaHolder === urlAgain.javaHolder)
  }

  func testJavaExceptionsInSwift() throws {
    if isLinux {
      throw XCTSkip("Attempts to refcount a null pointer on Linux")
    }

    do {
      _ = try URL("bad url", environment: jvm.environment)
    } catch {
      XCTAssert(String(describing: error) == "no protocol: bad url")
    }
  }

  func testStaticMethods() throws {
    if isLinux {
      throw XCTSkip("Attempts to refcount a null pointer on Linux")
    }

    let urlConnectionClass = try JavaClass<URLConnection>(in: jvm.environment)
    XCTAssert(urlConnectionClass.getDefaultAllowUserInteraction() == false)
  }

  func testClassInstanceLookup() throws {
    do {
      _ = try JavaClass<Nonexistent>(in: jvm.environment)
    } catch {
      XCTAssertEqual(String(describing: error), "org/swift/javakit/Nonexistent")
    }
  }
}

@JavaClass("org.swift.javakit.Nonexistent")
struct Nonexistent { }

/// Whether we're running on Linux.
var isLinux: Bool {
  #if os(Linux)
  return true
  #else
  return false
  #endif
}
