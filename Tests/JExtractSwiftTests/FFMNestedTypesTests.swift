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

import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

final class FFMNestedTypesTests {
  let class_interfaceFile =
    """
    public enum MyNamespace { }

    extension MyNamespace { 
      public struct MyNestedStruct { 
        public func test() {}
      }
    }
    """

  @Test("Import: Nested type in extension MyNamespace { struct MyName {} }")
  func test_nested_in_extension() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    guard let ty = st.importedTypes["MyNamespace.MyNestedStruct"] else {
      fatalError("Didn't import nested type!")
    }

    
    
  }

}