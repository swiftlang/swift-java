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
      "TestClass": SwiftTypeName(module: "Module1", name: "Class1"),
      "TestClass2": SwiftTypeName(module: "Module2", name: "Class1"),
      "TestClass3": SwiftTypeName(module: "Module1", name: "Class1"),
      "TestClass4": SwiftTypeName(module: nil, name: "Class1")
    ]

    XCTAssertThrowsError(try translator.validateClassConfiguration()) { error in
      XCTAssertTrue(error is JavaTranslator.ValidationError)
      let validationError = error as! JavaTranslator.ValidationError
      switch validationError {
      case .multipleClassesMappedToSameName(let swiftToJavaMapping):
        XCTAssertEqual(swiftToJavaMapping, [
          JavaTranslator.SwiftToJavaMapping(swiftType: .init(module: "Module1", name: "Class1"),
                                            javaTypes: ["TestClass", "TestClass3"])
        ])
      }
    }
  }
}
