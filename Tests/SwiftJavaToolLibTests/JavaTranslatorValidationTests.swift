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

import SwiftJavaToolLib
import XCTest

final class JavaTranslatorValidationTests: XCTestCase {
  func testValidationError() throws {
    let translator = try JavaTranslator(swiftModuleName: "SwiftModule", environment: jvm.environment())
    translator.translatedClasses = [
      "TestClass": ("Class1", "Module1"),
      "TestClass2": ("Class1", "Module2"),
      "TestClass3": ("Class1", "Module1"),
      "TestClass4": ("Class1", nil)
    ]

    XCTAssertThrowsError(try translator.validateClassConfiguration()) { error in
      XCTAssertTrue(error is JavaTranslator.ValidationError)
      let validationError = error as! JavaTranslator.ValidationError
      switch validationError {
      case .multipleClassesMappedToSameName(let swiftToJavaMapping):
        XCTAssertEqual(swiftToJavaMapping, [
          JavaTranslator.SwiftToJavaMapping(swiftType: .init(swiftType: "Class1", swiftModule: "Module1"),
                                            javaTypes: ["TestClass", "TestClass3"])
        ])
      }
    }
  }
}
