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
import JavaKitConfigurationShared
import JavaKitShared
import _Subprocess

extension JavaToSwift {

  var SwiftJavaClasspathPrefix: String { "SWIFT_JAVA_CLASSPATH:" }

  var printRuntimeClasspathTaskName: String { "printRuntimeClasspath" }

  func fetchDependencies(moduleName: String,
                         dependencies: [JavaDependencyDescriptor]) async throws -> ResolvedDependencyClasspath {
    let deps = dependencies.map { $0.descriptionGradleStyle }
    print("[debug][swift-java] Resolve and fetch dependencies for: \(deps)")

    let dependenciesClasspath = await resolveDependencies(dependencies: dependencies)
    let classpathEntries = dependenciesClasspath.split(separator: ":")


    print("[info][swift-java] Resolved classpath for \(deps.count) dependencies of '\(moduleName)', classpath entries: \(classpathEntries.count), ", terminator: "")
    print("done.".green)

    for entry in classpathEntries {
      print("[info][swift-java] Classpath entry: \(entry)")
    }

    return ResolvedDependencyClasspath(for: dependencies, classpath: dependenciesClasspath)
  }

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

    let process = try! await Subprocess.run(
      .at(.init(resolverDir.appendingPathComponent("gradlew").path)),
      arguments: [
        "--no-daemon",
        "--rerun-tasks",
        "\(printRuntimeClasspathTaskName)",
      ],
      workingDirectory: .init(platformString: resolverDir.path)
    )

    let outString = String(
      data: process.standardOutput,
      encoding: .utf8
    )
    let errString = String(
      data: process.standardError,
      encoding: .utf8
    )

    let classpathOutput: String
    if let found = outString?.split(separator: "\n").first(where: { $0.hasPrefix(self.SwiftJavaClasspathPrefix) }) {
      classpathOutput = String(found)
    } else if let found = errString?.split(separator: "\n").first(where: { $0.hasPrefix(self.SwiftJavaClasspathPrefix) }) {
      classpathOutput = String(found)
    } else {
      let suggestDisablingSandbox = "It may be that the Sandbox has prevented dependency fetching, please re-run with '--disable-sandbox'."
      fatalError("Gradle output had no SWIFT_JAVA_CLASSPATH! \(suggestDisablingSandbox). \n" +
        "Output was:<<<\(outString ?? "<empty>")>>>; Err was:<<<\(errString ?? "<empty>")>>>")
    }

    return String(classpathOutput.dropFirst(SwiftJavaClasspathPrefix.count))
  }

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

  mutating func writeFetchedDependenciesClasspath(
    moduleName: String,
    cacheDir: String,
    resolvedClasspath: ResolvedDependencyClasspath) throws {
    // Convert the artifact name to a module name
    // e.g. reactive-streams -> ReactiveStreams

    // The file contents are just plain
    let contents = resolvedClasspath.classpath

      print("[debug][swift-java] Resolved dependency: \(classpath)")

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

  func copyGradlew(to resolverWorkDirectory: URL) throws {
    var searchDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    while searchDir.pathComponents.count > 1 {
      print("[COPY] Search dir: \(searchDir)")
      
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

