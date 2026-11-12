//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaNet
import SwiftJava
import SwiftJavaRuntimeSupport
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Foundation values that jextract's `foundationTypesAsJavaTypes` passes as standard Java types.
class FoundationJavaValueTests: XCTestCase {
  private func roundTrip<T: JavaValue>(_ value: T) throws -> T where T.JNIType == jobject? {
    let environment = try JavaVirtualMachine.shared().environment()
    let object = value.getJNIValue(in: environment)
    defer { environment.interface.DeleteLocalRef(environment, object) }
    return T(fromJNI: object, in: environment)
  }

  func testURLIsJavaNetURI() throws {
    let environment = try JavaVirtualMachine.shared().environment()
    let url = URL(string: "https://swift.org/a%20b?q=1#top")!
    let object = url.getJNIValue(in: environment)
    XCTAssertEqual(URI(javaThis: object!, environment: environment).toString(), "https://swift.org/a%20b?q=1#top")
    XCTAssertEqual(try roundTrip(url), url)
  }

  func testDateKeepsMilliseconds() throws {
    XCTAssertEqual(try roundTrip(Date(timeIntervalSince1970: 1_700_000_000.123)).timeIntervalSince1970, 1_700_000_000.123)
    XCTAssertEqual(try roundTrip(Date(timeIntervalSince1970: -1.5)).timeIntervalSince1970, -1.5)
  }

  func testDataIsByteArray() throws {
    let environment = try JavaVirtualMachine.shared().environment()
    let data = Data([0, 1, 127, 128, 255])
    let array = data.getJNIValue(in: environment)
    defer { environment.interface.DeleteLocalRef(environment, array) }
    XCTAssertEqual(environment.interface.GetArrayLength(environment, array), 5)
    XCTAssertEqual(try roundTrip(data), data)
    XCTAssertEqual(try roundTrip(Data()), Data())
  }

  func testLocaleUsesLanguageTags() throws {
    XCTAssertEqual(try roundTrip(Locale(identifier: "pt_BR")).identifier, "pt_BR")
  }

  func testTimeZone() throws {
    XCTAssertEqual(try roundTrip(TimeZone(identifier: "America/New_York")!).identifier, "America/New_York")
  }
}
