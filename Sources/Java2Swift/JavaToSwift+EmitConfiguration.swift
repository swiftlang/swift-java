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
    classpath: String,
    environment: JNIEnvironment
  ) throws {
    print("[java-swift] Generate Java->Swift type mappings. Active filter: \(javaPackageFilter)")
    print("[java-swift] Classpath: \(classpath)")

    if classpath.isEmpty {
      print("[warning][java-swift] Classpath is empty!")
    }

    // Get a fresh or existing configuration we'll amend
    var (amendExistingConfig, configuration) = try getBaseConfigurationForWrite()
    if amendExistingConfig {
      print("[swift-java] Amend existing swift-java.config file...")
    }
    configuration.classpath = classpath // TODO: is this correct?

    // Import types from all the classpath entries;
    // Note that we use the package level filtering, so users have some control over what gets imported.
    for entry in classpath.split(separator: ":").map(String.init) {
      print("[debug][swift-java] Importing classpath entry: \(entry)")
      if entry.hasSuffix(".jar") {
        let jarFile = try JarFile(entry, false, environment: environment)
        try addJavaToSwiftMappings(
          to: &configuration,
          forJar: jarFile,
          environment: environment
        )
      } else if FileManager.default.fileExists(atPath: entry) {
        fatalError("[warning][swift-java] Currently unable handle directory classpath entries for config generation! Skipping: \(entry)")
      } else {
        print("[warning][swift-java] Classpath entry does not exist, skipping: \(entry)")
      }
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

  mutating func addJavaToSwiftMappings(
      to configuration: inout Configuration,
      forJar jarFile: JarFile,
      environment: JNIEnvironment
    ) throws {
    for entry in jarFile.entries()! {
      // We only look at class files in the Jar file.
      guard entry.getName().hasSuffix(".class") else {
        continue
      }

      // Skip some "common" files we know that would be duplicated in every jar
      guard !entry.getName().hasPrefix("META-INF") else {
        continue
      }
      guard !entry.getName().hasSuffix("package-info") else {
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

      if configuration.classes?[javaCanonicalName] != nil {
        // We never overwrite an existing class mapping configuration.
        // E.g. the user may have configured a custom name for a type.
        continue
      }

      configuration.classes?[javaCanonicalName] =
        javaCanonicalName.defaultSwiftNameForJavaClass
    }
  }

}