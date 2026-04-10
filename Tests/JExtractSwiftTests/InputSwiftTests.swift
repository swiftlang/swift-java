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
import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

@Suite
struct InputSwiftTests {
  let fileManager = FileManager.default

  @Test(arguments: [JExtractGenerationMode.jni, .ffm])
  func loadSwiftinterface(mode: JExtractGenerationMode) throws {
    let tempDirectory: URL = fileManager.temporaryDirectory
      .appending(path: "loadSwiftinterface-\(UUID())")
    let outSwiftURL = tempDirectory.appending(path: "swift")
    let outJavaURL = tempDirectory.appending(path: "java")

    try withTemporaryFile(
      fileName: "MyDependent",
      extension: "swiftinterface",
      contents: """
        public struct Foo {}
        """,
      in: tempDirectory
    ) { swiftInterfaceURL in
      var config = Configuration()
      config.mode = mode
      config.javaPackage = "com.example"
      config.inputSwiftDirectory = swiftInterfaceURL.absoluteURL.path()
      config.swiftModule = "MySwift"
      config.outputSwiftDirectory = outSwiftURL.absoluteURL.path()
      config.outputJavaDirectory = outJavaURL.absoluteURL.path()

      try SwiftToJava(config: config, dependentConfigs: [])
        .run()
    }

    let javaPackageRoot =
      outJavaURL
      .appending(path: "com")
      .appending(path: "example")
    let expectedSources: [URL] = [
      outSwiftURL.appending(path: "MySwiftModule+SwiftJava.swift"),
      outSwiftURL.appending(path: "MyDependent+SwiftJava.swift"),
      javaPackageRoot.appending(path: "Foo.java"),
      javaPackageRoot.appending(path: "MySwift.java"),
    ]

    for expectedSource in expectedSources {
      #expect(fileManager.fileExists(atPath: expectedSource.path()))
    }
  }

  @Test(arguments: [JExtractGenerationMode.jni, .ffm])
  func loadEmptySwiftinterface(mode: JExtractGenerationMode) throws {
    let tempDirectory: URL = fileManager.temporaryDirectory
      .appending(path: "loadEmptySwiftinterface-\(UUID())")
    let outSwiftURL = tempDirectory.appending(path: "swift")
    let outJavaURL = tempDirectory.appending(path: "java")

    try withTemporaryFile(
      fileName: "MyDependent",
      extension: "swiftinterface",
      contents: "",
      in: tempDirectory
    ) { swiftInterfaceURL in
      var config = Configuration()
      config.mode = mode
      config.writeEmptyFiles = true
      config.javaPackage = "com.example"
      config.inputSwiftDirectory = swiftInterfaceURL.absoluteURL.path()
      config.swiftModule = "MySwift"
      config.outputSwiftDirectory = outSwiftURL.absoluteURL.path()
      config.outputJavaDirectory = outJavaURL.absoluteURL.path()

      try SwiftToJava(config: config, dependentConfigs: [])
        .run()
    }

    let javaPackageRoot =
      outJavaURL
      .appending(path: "com")
      .appending(path: "example")
    let expectedSources: [URL] = [
      outSwiftURL.appending(path: "MySwiftModule+SwiftJava.swift"),
      outSwiftURL.appending(path: "MyDependent+SwiftJava.swift"),
      javaPackageRoot.appending(path: "MySwift.java"),
    ]

    for expectedSource in expectedSources {
      #expect(fileManager.fileExists(atPath: expectedSource.path()))
    }
  }
}
