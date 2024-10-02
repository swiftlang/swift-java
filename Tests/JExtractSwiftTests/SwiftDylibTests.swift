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

import JExtractSwift
import Testing

final class SwiftDylibTests {

  #if os(Linux)
  @Test(.disabled("Dylib.nm approach to getting symbol names not supported on Linux"))
  #else
  @Test
  #endif
  func test_nm() async throws {
    let dylib = SwiftDylib(path: ".build/arm64-apple-macosx/debug/libJavaKitExample.dylib")!

    let names = try await dylib.nmSymbolNames(grepDemangled: ["MySwiftClass", "len"])

    #expect(
      names.contains {
        $0.descriptiveName.contains("JavaKitExample.MySwiftClass.len.getter")
      }
    )

    let getter = names.findPropertyGetter()
    #expect(getter?.mangledName == "$s14JavaKitExample12MySwiftClassC3lenSivg")
    #expect(getter?.descriptiveName == "JavaKitExample.MySwiftClass.len.getter : Swift.Int")
  }
}
