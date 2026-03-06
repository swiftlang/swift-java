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

import Foundation
import XCTest

@testable import SwiftJavaToolLib

final class AndroidAPIVersionsParserTests: XCTestCase {

  // ===== ------------------------------------------------------------------------
  // MARK: - Tests

  func test_parseBasicClass() throws {
    let xml = """
      <api version="3">
        <class name="android/widget/TextView" since="1">
          <extends name="android/view/View"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)
    let info = versions.versionInfo(forClass: "android/widget/TextView")
    XCTAssertNotNil(info)
    XCTAssertEqual(info?.since, .BASE)
    XCTAssertNil(info?.removed)
    XCTAssertNil(info?.deprecated)
  }

  func test_parseClassWithDeprecatedAndRemoved() throws {
    let xml = """
      <api version="3">
        <class name="android/app/OldActivity" since="3" deprecated="15" removed="28">
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)
    let info = versions.versionInfo(forClass: "android/app/OldActivity")
    XCTAssertNotNil(info)
    XCTAssertEqual(info?.since, .CUPCAKE)
    XCTAssertEqual(info?.deprecated, .ICE_CREAM_SANDWICH_MR1)
    XCTAssertEqual(info?.removed, .P)
  }

  func test_parseMethodWithSince() throws {
    let xml = """
      <api version="3">
        <class name="android/view/Display" since="1">
          <method name="getDisplayId()I" since="17"/>
          <method name="&lt;init>()V"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)

    let methodInfo = versions.versionInfo(forClass: "android/view/Display", methodDescriptor: "getDisplayId()I")
    XCTAssertNotNil(methodInfo)
    XCTAssertEqual(methodInfo?.since, .JELLY_BEAN_MR1)

    // Constructor inherits class since
    let ctorInfo = versions.versionInfo(forClass: "android/view/Display", methodDescriptor: "<init>()V")
    XCTAssertNotNil(ctorInfo)
    XCTAssertEqual(ctorInfo?.since, .BASE)
  }

  func test_parseFieldWithDeprecatedAndRemoved() throws {
    let xml = """
      <api version="3">
        <class name="android/Manifest$permission" since="1">
          <field name="ACCEPT_HANDOVER" since="28"/>
          <field name="ACCESS_MOCK_LOCATION" removed="23"/>
          <field name="BIND_CARRIER_MESSAGING_SERVICE" since="22" deprecated="23"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)

    let f1 = versions.versionInfo(forClass: "android/Manifest$permission", fieldName: "ACCEPT_HANDOVER")
    XCTAssertEqual(f1?.since, .P)
    XCTAssertNil(f1?.removed)
    XCTAssertNil(f1?.deprecated)

    let f2 = versions.versionInfo(forClass: "android/Manifest$permission", fieldName: "ACCESS_MOCK_LOCATION")
    XCTAssertEqual(f2?.since, .BASE) // inherited from class
    XCTAssertEqual(f2?.removed, .M)

    let f3 = versions.versionInfo(forClass: "android/Manifest$permission", fieldName: "BIND_CARRIER_MESSAGING_SERVICE")
    XCTAssertEqual(f3?.since, .LOLLIPOP_MR1)
    XCTAssertEqual(f3?.deprecated, .M)
  }

  func test_memberInheritsSinceFromClass() throws {
    let xml = """
      <api version="3">
        <class name="android/app/Activity" since="5">
          <method name="onCreate(Landroid/os/Bundle;)V"/>
          <field name="RESULT_OK"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)

    // Method without explicit since inherits class since=5 (ECLAIR)
    let methodInfo = versions.versionInfo(forClass: "android/app/Activity", methodDescriptor: "onCreate(Landroid/os/Bundle;)V")
    XCTAssertEqual(methodInfo?.since, .ECLAIR)

    // Field without explicit since inherits class since=5 (ECLAIR)
    let fieldInfo = versions.versionInfo(forClass: "android/app/Activity", fieldName: "RESULT_OK")
    XCTAssertEqual(fieldInfo?.since, .ECLAIR)
  }

  func test_classNameDotFormatQuery() throws {
    let xml = """
      <api version="3">
        <class name="android/widget/Button" since="1">
          <field name="STYLE" since="21"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)

    // Query using dot format
    let classInfo = versions.versionInfo(forClass: "android.widget.Button")
    XCTAssertNotNil(classInfo)
    XCTAssertEqual(classInfo?.since, .BASE)

    let fieldInfo = versions.versionInfo(forClass: "android.widget.Button", fieldName: "STYLE")
    XCTAssertEqual(fieldInfo?.since, .LOLLIPOP)
  }

  func test_classWithNoSince() throws {
    let xml = """
      <api version="3">
        <class name="android/os/Build">
          <field name="BOARD"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)

    let classInfo = versions.versionInfo(forClass: "android/os/Build")
    XCTAssertNotNil(classInfo)
    XCTAssertNil(classInfo?.since) // no since attribute

    // Field also has nil since (inherits nil from class)
    let fieldInfo = versions.versionInfo(forClass: "android/os/Build", fieldName: "BOARD")
    XCTAssertNotNil(fieldInfo)
    XCTAssertNil(fieldInfo?.since)
  }

  func test_queryNonexistentClassReturnsNil() throws {
    let xml = """
      <api version="3">
        <class name="android/widget/TextView" since="1"/>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)

    XCTAssertNil(versions.versionInfo(forClass: "android/nonexistent/Class"))
    XCTAssertNil(versions.versionInfo(forClass: "android/widget/TextView", methodDescriptor: "noSuchMethod()V"))
    XCTAssertNil(versions.versionInfo(forClass: "android/widget/TextView", fieldName: "NO_SUCH_FIELD"))
  }

  func test_stats() throws {
    let xml = """
      <api version="3">
        <class name="android/app/Activity" since="1">
          <method name="onCreate(Landroid/os/Bundle;)V"/>
          <method name="onDestroy()V"/>
          <field name="RESULT_OK"/>
        </class>
        <class name="android/widget/Button" since="1">
          <method name="&lt;init>(Landroid/content/Context;)V"/>
          <field name="STYLE" since="21"/>
          <field name="MODE" since="23"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)
    let stats = versions.stats()
    XCTAssertEqual(stats.classCount, 2)
    XCTAssertEqual(stats.methodCount, 3) // 2 Activity methods + 1 Button constructor
    XCTAssertEqual(stats.fieldCount, 3) // 1 Activity field + 2 Button fields
  }

  func test_multipleClasses() throws {
    let xml = """
      <api version="3">
        <class name="android/app/Activity" since="1">
          <field name="RESULT_OK"/>
        </class>
        <class name="android/content/Context" since="1">
          <method name="getSystemService(Ljava/lang/String;)Ljava/lang/Object;" since="1"/>
        </class>
        <class name="android/os/Build$VERSION" since="4">
          <field name="SDK_INT" since="4"/>
        </class>
      </api>
      """
    let versions = try AndroidAPIVersionsParser.parse(string: xml)

    XCTAssertEqual(versions.versionInfo(forClass: "android/app/Activity")?.since, .BASE)
    XCTAssertEqual(versions.versionInfo(forClass: "android/content/Context")?.since, .BASE)
    XCTAssertEqual(versions.versionInfo(forClass: "android/os/Build$VERSION")?.since, .DONUT)
    XCTAssertEqual(versions.versionInfo(forClass: "android/os/Build$VERSION", fieldName: "SDK_INT")?.since, .DONUT)
  }

  func test_parseRealFile() throws {
    // Try to parse the real api-versions.xml if it exists on this machine
    let possiblePaths = [
      "\(NSHomeDirectory())/Library/Android/sdk/platforms/android-35/data/api-versions.xml",
      "\(NSHomeDirectory())/Library/Android/sdk/platforms/android-34/data/api-versions.xml",
    ]
    guard let path = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
      // Skip test if no Android SDK is installed
      throw XCTSkip("No Android SDK api-versions.xml found on this machine")
    }

    let url = URL(fileURLWithPath: path)
    let versions = try AndroidAPIVersionsParser.parse(contentsOf: url)
    let stats = versions.stats()

    // The real file should have a significant amount of data
    XCTAssertGreaterThan(stats.classCount, 1000, "Expected many classes in real api-versions.xml")
    XCTAssertGreaterThan(stats.methodCount, 10000, "Expected many methods in real api-versions.xml")
    XCTAssertGreaterThan(stats.fieldCount, 1000, "Expected many fields in real api-versions.xml")

    // Spot-check some well-known classes
    let activityInfo = versions.versionInfo(forClass: "android/app/Activity")
    XCTAssertNotNil(activityInfo, "android.app.Activity should exist")
    XCTAssertEqual(activityInfo?.since, .BASE)
  }
}
