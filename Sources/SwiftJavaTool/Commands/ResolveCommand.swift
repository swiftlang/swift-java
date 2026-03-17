//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import Foundation
import JavaUtilJar
import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import SwiftJavaToolLib

typealias Configuration = SwiftJavaConfigurationShared.Configuration

extension SwiftJava {
  struct ResolveCommand: SwiftJavaBaseAsyncParsableCommand, HasCommonOptions, HasCommonJVMOptions {
    static let configuration = CommandConfiguration(
      commandName: "resolve",
      abstract: "Resolve dependencies and write the resulting swift-java.classpath file"
    )

    @OptionGroup var commonOptions: SwiftJava.CommonOptions
    @OptionGroup var commonJVMOptions: SwiftJava.CommonJVMOptions

    @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
    var swiftModule: String

    var effectiveSwiftModule: String {
      swiftModule
    }

    @Argument(
      help: """
        Additional configuration paths (swift-java.config) files, with defined 'dependencies', \
        or dependency descriptors formatted as 'groupID:artifactID:version' separated by ','. \
        May be empty, in which case the target Swift module's configuration's 'dependencies' will be used.
        """
    )
    var input: String?
  }
}

extension SwiftJava.ResolveCommand {
  var SwiftJavaClasspathPrefix: String { "SWIFT_JAVA_CLASSPATH:" }
  var printRuntimeClasspathTaskName: String { "printRuntimeClasspath" }

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    var dependenciesToResolve: [JavaDependencyDescriptor] = []
    if let input, let inputDependencies = parseDependencyDescriptor(input) {
      dependenciesToResolve.append(inputDependencies)
    }
    if let dependencies = config.dependencies {
      dependenciesToResolve += dependencies
    }

    if dependenciesToResolve.isEmpty {
      print(
        "[warn][swift-java] Attempted to 'resolve' dependencies but no dependencies specified in swift-java.config or command input!"
      )
      return
    }

    let dependenciesClasspath =
      try await resolveDependencies(swiftModule: swiftModule, dependencies: dependenciesToResolve)

    // FIXME: disentangle the output directory from SwiftJava and then make it a required option in this Command
    guard let outputDirectory = self.commonOptions.outputDirectory else {
      fatalError(
        "error: Must specify --output-directory in 'resolve' mode! This option will become explicitly required"
      )
    }

    try writeSwiftJavaClasspathFile(
      swiftModule: swiftModule,
      outputDirectory: outputDirectory,
      resolvedClasspath: dependenciesClasspath
    )
  }

  /// Resolves Java dependencies from swift-java.config and returns classpath information.
  ///
  /// - Parameters:
  ///   - swiftModule: module name from --swift-module. e.g.: --swift-module MySwiftModule
  ///   - dependencies: parsed maven-style dependency descriptors (groupId:artifactId:version)
  ///                   from Sources/MySwiftModule/swift-java.config "dependencies" array.
  ///
  /// - Throws:
  func resolveDependencies(
    swiftModule: String,
    dependencies: [JavaDependencyDescriptor]
  ) async throws -> ResolvedDependencyClasspath {
    let deps = dependencies.map { $0.descriptionGradleStyle }
    print("[debug][swift-java] Resolve and fetch dependencies for: \(deps)")

    let workDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(".build")

    let dependenciesClasspath = await resolveDependencies(workDir: workDir, dependencies: dependencies)
    let classpathEntries = dependenciesClasspath.split(separator: ":")

    print(
      "[info][swift-java] Resolved classpath for \(deps.count) dependencies of '\(swiftModule)', classpath entries: \(classpathEntries.count), ",
      terminator: ""
    )
    print("done.".green)

    for entry in classpathEntries {
      print("[info][swift-java] Classpath entry: \(entry)")
    }

    return ResolvedDependencyClasspath(for: dependencies, classpath: dependenciesClasspath)
  }

  /// Resolves maven-style dependencies from swift-java.config under temporary project directory.
  ///
  /// - Parameter dependencies: maven-style dependencies to resolve
  /// - Returns: Colon-separated classpath
  func resolveDependencies(
    workDir: URL,
    dependencies: [JavaDependencyDescriptor],
    repositories: [JavaRepositoryDescriptor]? = nil
  ) async -> String {
    print("Create directory: \(workDir.absoluteString)")

    var resolveConfig = SwiftJavaConfigurationShared.Configuration()
    resolveConfig.dependencies = dependencies
    resolveConfig.repositories = repositories

    if #available(macOS 15, *) {
      do {
        return try await JavaResolver.resolve(config: resolveConfig, workDir: workDir)
      } catch {
        fatalError("Failed to resolve dependencies: \(error)")
      }
    } else {
      fatalError("Subprocess is unavailable yet required to execute `gradlew` subprocess. Please update to macOS 15+")
    }
  }

  /// Creates {MySwiftModule}.swift.classpath in the --output-directory.
  ///
  /// - Parameters:
  ///   - swiftModule: Swift module name for classpath filename (--swift-module value)
  ///   - outputDirectory: Directory path for classpath file (--output-directory value)
  ///   - resolvedClasspath: Complete dependency classpath information
  ///
  mutating func writeSwiftJavaClasspathFile(
    swiftModule: String,
    outputDirectory: String,
    resolvedClasspath: ResolvedDependencyClasspath
  ) throws {
    // Convert the artifact name to a module name
    // e.g. reactive-streams -> ReactiveStreams

    // The file contents are just plain
    let contents = resolvedClasspath.classpath

    let filename = "\(swiftModule).swift-java.classpath"
    print("[debug][swift-java] Write resolved dependencies to: \(outputDirectory)/\(filename)")

    // Write the file
    try writeContents(
      contents,
      outputDirectory: URL(fileURLWithPath: outputDirectory),
      to: filename,
      description: "swift-java.classpath file for module \(swiftModule)"
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
