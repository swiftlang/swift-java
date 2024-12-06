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
import Java2SwiftLib
import JavaKit
import Foundation
import JavaKitJar
import Java2SwiftLib
import JavaKitDependencyResolver
import JavaKitConfigurationShared
import JavaKitShared

extension JavaToSwift {

  /// Must be the same as `DependencyResolver#CLASSPATH_CACHE_FILENAME` on the java side.
  var JavaKitDependencyResolverClasspathCacheFilename: String {
    "JavaKitDependencyResolver.swift-java.classpath"
  }
  var JavaKitDependencyResolverClasspathCacheFilePath: String {
    ".build/\(JavaKitDependencyResolverClasspathCacheFilename)"
  }

  func fetchDependenciesCachedClasspath() -> [String]? {
    guard let cachedClasspathURL = URL(string: "file://" + FileManager.default.currentDirectoryPath + "/" + JavaKitDependencyResolverClasspathCacheFilePath) else {
      return []
    }

    guard FileManager.default.fileExists(atPath: cachedClasspathURL.path) else {
      return []
    }

    guard let javaKitDependencyResolverCachedClasspath = try? String(contentsOf: cachedClasspathURL) else {
      return []
    }

    print("[debug][swift-java] Cached dependency resolver classpath: \(javaKitDependencyResolverCachedClasspath)")
    return javaKitDependencyResolverCachedClasspath.split(separator: ":").map(String.init)
  }

  func fetchDependencies(moduleName: String,
                         dependencies: [JavaDependencyDescriptor],
                         baseClasspath: [String],
                         environment: JNIEnvironment) throws -> ResolvedDependencyClasspath {
    let deps = dependencies.map { $0.descriptionGradleStyle }
    print("[debug][swift-java] Resolve and fetch dependencies for: \(deps)")
    let resolverClass = try JavaClass<DependencyResolver>(environment: environment)

      let fullClasspath = try resolverClass.resolveDependenciesToClasspath(
        projectBaseDirectory: URL(fileURLWithPath: ".").path,
        dependencies: deps)
        .split(separator: ":")

    let classpathEntries = fullClasspath.filter {
      $0.hasSuffix(".jar")
    }
    let classpath = classpathEntries.joined(separator: ":")

    print("[info][swift-java] Resolved classpath for \(deps.count) dependencies of '\(moduleName)', classpath entries: \(classpathEntries.count), ", terminator: "")
    print("done.".green)

    return ResolvedDependencyClasspath(for: dependencies, classpath: classpath)
  }
}

extension JavaToSwift {
  mutating func writeFetchedDependenciesClasspath(
    moduleName: String,
    cacheDir: String,
    resolvedClasspath: ResolvedDependencyClasspath) throws {
    // Convert the artifact name to a module name
    // e.g. reactive-streams -> ReactiveStreams

    // The file contents are just plain
    let contents = resolvedClasspath.classpath

    // Write the file
    try writeContents(
      contents,
      outputDirectoryOverride: URL(fileURLWithPath: cacheDir),
      to: "\(moduleName).swift-java.classpath",
      description: "swift-java.classpath file for module \(moduleName)"
    )
  }

  public func artifactIDAsModuleID(_ artifactID: String) -> String {
    let components = artifactID.split(whereSeparator: { $0 == "-" })
    let camelCased = components.map { $0.capitalized }.joined()
    return camelCased
  }
}

struct ResolvedDependencyClasspath: CustomStringConvertible {
  /// The dependency identifiers this is the classpath for.
  let rootDependencies: [JavaDependencyDescriptor]

  /// Plain string representation of a Java classpath
  let classpath: String

  var classpathEntries: [String] {
    classpath.split(separator: ":").map(String.init)
  }

  init(for rootDependencies: [JavaDependencyDescriptor], classpath: String) {
    self.rootDependencies = rootDependencies
    self.classpath = classpath
  }

  var description: String {
    "JavaClasspath(for: \(rootDependencies), classpath: \(classpath))"
  }
}
