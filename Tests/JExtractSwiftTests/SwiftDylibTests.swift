//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JExtractSwift
import XCTest

final class SwiftDylibTests: XCTestCase {
  func test_nm() async throws {
    let dylib = SwiftDylib(path: ".build/arm64-apple-macosx/debug/libJavaKitExample.dylib")!

    let names = try await dylib.nmSymbolNames(grepDemangled: ["MySwiftClass", "len"])

    XCTAssertTrue(
      names.contains {
        $0.descriptiveName.contains("JavaKitExample.MySwiftClass.len.getter")
      }
    )

    let getter = names.findPropertyGetter()
    XCTAssertEqual(getter?.mangledName, "$s14JavaKitExample12MySwiftClassC3lenSivg")
    XCTAssertEqual(getter?.descriptiveName, "JavaKitExample.MySwiftClass.len.getter : Swift.Int")
  }
}
