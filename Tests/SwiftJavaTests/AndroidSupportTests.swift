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

@_spi(Testing) import SwiftJava
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

class AndroidSupportTests: XCTestCase {
  func testDesugaredName() throws {
    XCTAssertEqual(AndroidSupport._desugaredName(forDotted: "java.util.Optional"), "j$.util.Optional")
    XCTAssertEqual(AndroidSupport._desugaredName(forDotted: "java.util.OptionalInt"), "j$.util.OptionalInt")
    XCTAssertEqual(AndroidSupport._desugaredName(forDotted: "java.util.OptionalLong"), "j$.util.OptionalLong")
    XCTAssertEqual(AndroidSupport._desugaredName(forDotted: "java.util.OptionalDouble"), "j$.util.OptionalDouble")

    XCTAssertNil(AndroidSupport._desugaredName(forDotted: "java.lang.String"))
    XCTAssertNil(AndroidSupport._desugaredName(forDotted: "java.util.List"))
    XCTAssertNil(AndroidSupport._desugaredName(forDotted: "org.example.Foo"))
  }

  func testRewriteDescriptor() throws {
    // `androidDesugarClassNameConversionWithSlashes` is identity on macOS/Linux, so a test-local
    // mapping is injected to exercise the descriptor-scanning logic itself.
    let mapping: (String) -> String = { className in
      className == "java/util/Optional" ? "j$/util/Optional" : className
    }

    XCTAssertEqual(
      AndroidSupport._rewriteDescriptor("()Ljava/util/Optional;", mapping: mapping),
      "()Lj$/util/Optional;"
    )
    XCTAssertEqual(
      AndroidSupport._rewriteDescriptor("(Ljava/lang/Object;)Ljava/util/Optional;", mapping: mapping),
      "(Ljava/lang/Object;)Lj$/util/Optional;"
    )
    XCTAssertEqual(
      AndroidSupport._rewriteDescriptor("([Ljava/util/Optional;IJ)V", mapping: mapping),
      "([Lj$/util/Optional;IJ)V"
    )
    XCTAssertEqual(
      AndroidSupport._rewriteDescriptor("()Z", mapping: mapping),
      "()Z"
    )
  }
}
