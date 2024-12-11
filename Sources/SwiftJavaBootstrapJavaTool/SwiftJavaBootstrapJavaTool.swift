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
import Synchronization
import JavaKitConfigurationShared
import Dispatch
import _Subprocess

@available(macOS 15.0, *)
@main
final class SwiftJavaBootstrapJavaTool {
  
  let SwiftJavaClasspathPrefix = "SWIFT_JAVA_CLASSPATH:"
  
  // We seem to have weird "hang" issues with Gradle launched from Process(), workaround it by existing once we get the classpath
  let printRuntimeClasspathTaskName = "printRuntimeClasspath"
  
  let out = Synchronization.Mutex<Data>(Data())
  let err = Synchronization.Mutex<Data>(Data())
  
  static func main() async throws {
    try await SwiftJavaBootstrapJavaTool().run()
  }
  
  func run() async throws {
    print("[debug][swift-java-bootstrap] RUN SwiftJavaBootstrapJavaTool: \(CommandLine.arguments.joined(separator: " "))")
    
    var args = CommandLine.arguments
    _ = args.removeFirst() // executable
    
    assert(args.removeFirst() == "--fetch")
    let configPath = args.removeFirst()
    
    assert(args.removeFirst() == "--module-name")
    let moduleName = args.removeFirst()
    
    assert(args.removeFirst() == "--output-directory")
    let outputDirectoryPath = args.removeFirst()

    let configPathURL = URL(fileURLWithPath: configPath)
    print("[debug][swift-java-bootstrap] Load config: \(configPathURL.absoluteString)")
    let config = try readConfiguration(configPath: configPathURL)
    
    // We only support a single dependency right now.
    let localGradleProjectDependencyName = (config.dependencies ?? []).filter {
      $0.artifactID.hasPrefix(":")
    }.map {
      $0.artifactID
    }.first!
    
    let process = try await Subprocess.run(
      .at("./gradlew"),
      arguments: [
        "--no-daemon",
        "--rerun-tasks",
  //      "--debug",
  //      "\(localGradleProjectDependencyName):jar",
        "\(localGradleProjectDependencyName):\(printRuntimeClasspathTaskName)"
      ]
    )
    
    let outString = String(
        data: process.standardOutput,
        encoding: .utf8
    )
    let errString = String(
      data: process.standardError,
        encoding: .utf8
    )
    
    print("OUT ==== \(outString?.count) ::: \(outString ?? "")")
    print("ERR ==== \(errString?.count) ::: \(errString ?? "")")
    
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
    
    let classpathString = String(classpathOutput.dropFirst(self.SwiftJavaClasspathPrefix.count))
    
    let classpathOutputURL =
      URL(fileURLWithPath: outputDirectoryPath)
        .appendingPathComponent("\(moduleName).swift-java.classpath", isDirectory: false)
    
    try! classpathString.write(to: classpathOutputURL, atomically: true, encoding: .utf8)
    
    print("[swift-java-bootstrap] Done, written classpath to: \(classpathOutputURL)")
  }
  
  func writeBuildGradle(directory: URL) {
    //    """
    //    plugins { id 'java-library' }
    //    repositories { mavenCentral() }
    //
    //    dependencies {
    //        implementation("dev.gradleplugins:gradle-api:8.10.1")
    //    }
    //
    //    task \(printRuntimeClasspathTaskName) {
    //        def runtimeClasspath = sourceSets.main.runtimeClasspath
    //        inputs.files(runtimeClasspath)
    //        doLast {
    //            println("CLASSPATH:${runtimeClasspath.asPath}")
    //        }
    //    }
    //    """.write(to: URL(fileURLWithPath: tempDir.appendingPathComponent("build.gradle")).path(percentEncoded: false), atomically: true, encoding: .utf8)
    //
    //    """
    //    rootProject.name = "swift-java-resolve-temp-project"
    //    """.write(to: URL(fileURLWithPath: tempDir.appendingPathComponent("settings.gradle.kts")).path(percentEncoded: false), atomically: true, encoding: .utf8)
  }
  
}
