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

import Foundation
import ArgumentParser
import Java2SwiftLib
import JavaKit
import JavaKitJar
import Java2SwiftLib
import JavaKitDependencyResolver
import JavaKitConfigurationShared

extension JavaToSwift {
  mutating func emitConfiguration(
    forJarFile jarFileName: String,
    classPath: String,
    environment: JNIEnvironment
  ) throws {
    var configuration = Configuration()
    configuration.classPath = classPath

    let jarFile = try JarFile(jarFileName, false, environment: environment)
    for entry in jarFile.entries()! {
      // We only look at class files in the Jar file.
      guard entry.getName().hasSuffix(".class") else {
        continue
      }

      // If this is a local class, it cannot be mapped into Swift.
      if entry.getName().isLocalJavaClass {
        continue
      }

      let javaCanonicalName = String(entry.getName().replacing("/", with: ".")
        .dropLast(".class".count))
      configuration.classes?[javaCanonicalName] =
        javaCanonicalName.defaultSwiftNameForJavaClass
    }

    // Encode the configuration.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var contents = String(data: try encoder.encode(configuration), encoding: .utf8)!
    contents.append("\n")

    // Write the file.
    try writeContents(
      contents,
      to: "swift-java.config",
      description: "swift-java configuration file"
    )
  }
}