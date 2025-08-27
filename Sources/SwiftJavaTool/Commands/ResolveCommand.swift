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
import SwiftJavaToolLib
import SwiftJava
import Foundation
import JavaUtilJar
import SwiftJavaToolLib
import SwiftJavaConfigurationShared
import SwiftJavaShared
import _Subprocess
#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

typealias Configuration = SwiftJavaConfigurationShared.Configuration

extension SwiftJava {
  struct ResolveCommand: SwiftJavaBaseAsyncParsableCommand, HasCommonOptions, HasCommonJVMOptions {
    static let configuration = CommandConfiguration(
      commandName: "resolve",
      abstract: "Resolve dependencies and write the resulting swift-java.classpath file")

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
      print("[warn][swift-java] Attempted to 'resolve' dependencies but no dependencies specified in swift-java.config or command input!")
      return
    }

    let dependenciesClasspath =
      try await resolveDependencies(swiftModule: swiftModule, dependencies: dependenciesToResolve)

    // FIXME: disentangle the output directory from SwiftJava and then make it a required option in this Command
    guard let outputDirectory = self.commonOptions.outputDirectory else {
      fatalError("error: Must specify --output-directory in 'resolve' mode! This option will become explicitly required")
    }

    try writeSwiftJavaClasspathFile(
      swiftModule: swiftModule,
      outputDirectory: outputDirectory,
      resolvedClasspath: dependenciesClasspath)
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
    swiftModule: String, dependencies: [JavaDependencyDescriptor]
  ) async throws -> ResolvedDependencyClasspath {
    let deps = dependencies.map { $0.descriptionGradleStyle }
    print("[debug][swift-java] Resolve and fetch dependencies for: \(deps)")

    let dependenciesClasspath = await resolveDependencies(dependencies: dependencies)
    let classpathEntries = dependenciesClasspath.split(separator: ":")

    print("[info][swift-java] Resolved classpath for \(deps.count) dependencies of '\(swiftModule)', classpath entries: \(classpathEntries.count), ", terminator: "")
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
  func resolveDependencies(dependencies: [JavaDependencyDescriptor]) async -> String {
    let workDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(".build")
    let resolverDir = try! createTemporaryDirectory(in: workDir)
    defer {
      try? FileManager.default.removeItem(at: resolverDir)
    }

    // We try! because it's easier to track down errors like this than when we bubble up the errors,
    // and don't get great diagnostics or backtraces due to how swiftpm plugin tools are executed.
    
    try! copyGradlew(to: resolverDir)

    try! printGradleProject(directory: resolverDir, dependencies: dependencies)

    if #available(macOS 15, *) {
      let process = try! await _Subprocess.run(
        .path(FilePath(resolverDir.appendingPathComponent("gradlew").path)),
        arguments: [
          "--no-daemon",
          "--rerun-tasks",
          "\(printRuntimeClasspathTaskName)",
        ],
        workingDirectory: Optional(FilePath(resolverDir.path)),
        // TODO: we could move to stream processing the outputs
        output: .string(limit: Int.max, encoding: UTF8.self), // Don't limit output, we know it will be reasonable size
        error: .string(limit: Int.max, encoding: UTF8.self) // Don't limit output, we know it will be reasonable size
      )

      let outString = process.standardOutput ?? ""
      let errString = process.standardError ?? ""

      let classpathOutput: String
      if let found = outString.split(separator: "\n").first(where: { $0.hasPrefix(self.SwiftJavaClasspathPrefix) }) {
        classpathOutput = String(found)
      } else if let found = errString.split(separator: "\n").first(where: { $0.hasPrefix(self.SwiftJavaClasspathPrefix) }) {
        classpathOutput = String(found)
      } else {
        let suggestDisablingSandbox = "It may be that the Sandbox has prevented dependency fetching, please re-run with '--disable-sandbox'."
        fatalError("Gradle output had no SWIFT_JAVA_CLASSPATH! \(suggestDisablingSandbox). \n" +
          "Output was:<<<\(outString)>>>; Err was:<<<\(errString ?? "<empty>")>>>")
      }

      return String(classpathOutput.dropFirst(SwiftJavaClasspathPrefix.count))
    } else {
      // Subprocess is unavailable
      fatalError("Subprocess is unavailable yet required to execute `gradlew` subprocess. Please update to macOS 15+")
    }
  }

  /// Creates Gradle project files (build.gradle, settings.gradle.kts) in temporary directory.
  func printGradleProject(directory: URL, dependencies: [JavaDependencyDescriptor]) throws {
    let buildGradle = directory
      .appendingPathComponent("build.gradle", isDirectory: false)

    let buildGradleText =
      """
      plugins { id 'java-library' }
      repositories { mavenCentral() }

      dependencies {
        \(dependencies.map({ dep in "implementation(\"\(dep.descriptionGradleStyle)\")" }).joined(separator: ",\n"))
      }

      tasks.register("printRuntimeClasspath") {
          def runtimeClasspath = sourceSets.main.runtimeClasspath
          inputs.files(runtimeClasspath)
          doLast {
              println("\(SwiftJavaClasspathPrefix)${runtimeClasspath.asPath}")
          }
      }
      """
    try buildGradleText.write(to: buildGradle, atomically: true, encoding: .utf8)

    let settingsGradle = directory
      .appendingPathComponent("settings.gradle.kts", isDirectory: false)
    let settingsGradleText =
      """
      rootProject.name = "swift-java-resolve-temp-project"
      """
    try settingsGradleText.write(to: settingsGradle, atomically: true, encoding: .utf8)
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
    resolvedClasspath: ResolvedDependencyClasspath) throws {
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

  // copy gradlew & gradle.bat from root, throws error if there is no gradle setup.
  func copyGradlew(to resolverWorkDirectory: URL) throws {
    var searchDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    while searchDir.pathComponents.count > 1 {
      let gradlewFile = searchDir.appendingPathComponent("gradlew")
      let gradlewExists = FileManager.default.fileExists(atPath: gradlewFile.path)
      guard gradlewExists else {
        searchDir = searchDir.deletingLastPathComponent()
        continue
      }
      
      let gradlewBatFile = searchDir.appendingPathComponent("gradlew.bat")
      let gradlewBatExists = FileManager.default.fileExists(atPath: gradlewFile.path)
      
      let gradleDir = searchDir.appendingPathComponent("gradle")
      let gradleDirExists = FileManager.default.fileExists(atPath: gradleDir.path)
      guard gradleDirExists else {
        searchDir = searchDir.deletingLastPathComponent()
        continue
      }
      
      // TODO: gradle.bat as well
      try? FileManager.default.copyItem(
        at: gradlewFile,
        to: resolverWorkDirectory.appendingPathComponent("gradlew"))
      if gradlewBatExists {
        try? FileManager.default.copyItem(
          at: gradlewBatFile,
          to: resolverWorkDirectory.appendingPathComponent("gradlew.bat"))
      }
      try? FileManager.default.copyItem(
        at: gradleDir,
        to: resolverWorkDirectory.appendingPathComponent("gradle"))
      return
    }
  }

  func createTemporaryDirectory(in directory: URL) throws -> URL {
    let uuid = UUID().uuidString
    let resolverDirectoryURL = directory.appendingPathComponent("swift-java-dependencies-\(uuid)")

    try FileManager.default.createDirectory(at: resolverDirectoryURL, withIntermediateDirectories: true, attributes: nil)

    return resolverDirectoryURL
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

