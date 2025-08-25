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

import SwiftJava
import JavaNet
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

/// Handy reference to the JVM abstraction.
var jvm: JavaVirtualMachine {
  get throws {
    try .shared()
  }
}

class BasicRuntimeTests: XCTestCase {
  func testJavaObjectManagement() throws {
    let environment = try jvm.environment()
    let sneakyJavaThis: jobject
    do {
      let object = JavaObject(environment: environment)
      XCTAssert(object.toString().starts(with: "java.lang.Object"))

      // Make sure this object was promoted to a global reference.
      XCTAssertEqual(object.javaEnvironment.pointee?.pointee.GetObjectRefType(object.javaEnvironment, object.javaThis), JNIGlobalRefType)

      // Keep track of the Java object.
      sneakyJavaThis = object.javaThis
    }

    // The reference should now be invalid, because we've deleted the
    // global reference.
    XCTAssertEqual(environment.pointee?.pointee.GetObjectRefType(environment, sneakyJavaThis), JNIInvalidRefType)

    // 'super' and 'as' don't require allocating a new holder.
    let url = try URL("http://swift.org", environment: environment)
    let superURL: JavaObject = url
    XCTAssert(url.javaHolder === superURL.javaHolder)
    let urlAgain = superURL.as(URL.self)!
    XCTAssert(url.javaHolder === urlAgain.javaHolder)
  }

  func testJavaExceptionsInSwift() throws {
    let environment = try jvm.environment()

    do {
      _ = try URL("bad url", environment: environment)
    } catch {
      XCTAssertEqual(String(describing: error), "java.net.MalformedURLException: no protocol: bad url")
    }
  }

  func testStaticMethods() throws {
    let environment = try jvm.environment()

    let urlConnectionClass = try JavaClass<URLConnection>(environment: environment)
    XCTAssert(urlConnectionClass.getDefaultAllowUserInteraction() == false)
  }

  func testClassInstanceLookup() throws {
    let environment = try jvm.environment()

    do {
      _ = try JavaClass<Nonexistent>(environment: environment)
    } catch {
      XCTAssertEqual(String(describing: error), "java.lang.NoClassDefFoundError: org/swift/javakit/Nonexistent")
    }
  }

  func testNullJavaStringConversion() throws {
    let environment = try jvm.environment()
    let nullString = String(fromJNI: nil, in: environment)
    XCTAssertEqual(nullString, "")
  }
}

@JavaClass("org.swift.javakit.Nonexistent")
struct Nonexistent { }
