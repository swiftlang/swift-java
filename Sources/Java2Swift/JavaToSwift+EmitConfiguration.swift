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

  // TODO: make this perhaps "emit type mappings"
  mutating func emitConfiguration(
    forJarFile jarFileName: String,
    classpath: String,
    environment: JNIEnvironment
  ) throws {
    // Get a fresh or existing configuration we'll amend
    var (amendExistingConfig, configuration) = try getBaseConfigurationForWrite()
    if amendExistingConfig {
      print("[java-swift] Amend existing swift-java.config file...")
    } else {
      configuration.classpath = classpath // TODO: is this correct?
    }

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

      if let javaPackageFilter {
        if !javaCanonicalName.hasPrefix(javaPackageFilter) {
          // Skip classes which don't match our expected prefix
          continue
        }
      }

      if amendExistingConfig && configuration.classes?[javaCanonicalName] != nil {
        // If we're amending an existing config, we never overwrite an existing
        // class configuration. E.g. the user may have configured a custom name
        // for a type.
        continue
      }
      configuration.classes?[javaCanonicalName] =
        javaCanonicalName.defaultSwiftNameForJavaClass
    }

    // Encode the configuration.
    let contents = try configuration.renderJSON()

    // Write the file.
    try writeContents(
      contents,
      to: "swift-java.config",
      description: "swift-java configuration file"
    )
  }
}