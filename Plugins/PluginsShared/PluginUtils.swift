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
import PackagePlugin

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    return home
  }

  // This is a workaround for envs (some IDEs) which have trouble with
  // picking up env variables during the build process
  let path = "\(FileManager.default.homeDirectoryForCurrentUser.path()).java_home"
  if let home = try? String(contentsOfFile: path, encoding: .utf8) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }

    return home
  }

  if let home = getJavaHomeFromSDKMAN() {
    return home
  }

  if let home = getJavaHomeFromPath() {
    return home
  }

  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}

func getSwiftJavaConfigPath(target: Target) -> String? {
  let configPath = URL(fileURLWithPath: target.directory.string).appending(component: "swift-java.config").path()

  if FileManager.default.fileExists(atPath: configPath) {
    return configPath
  } else {
    return nil
  }
}

func getEnvironmentBool(_ name: String) -> Bool {
  if let value = ProcessInfo.processInfo.environment[name] {
    switch value.lowercased() {
    case "true", "yes", "1": true
    case "false", "no", "0": false
    default: false
    }
  } else {
    false
  }
}

extension PluginContext {
  var outputJavaDirectory: URL {
    self.pluginWorkDirectoryURL
      .appending(path: "src")
      .appending(path: "generated")
      .appending(path: "java")
  }

  var outputSwiftDirectory: URL {
    self.pluginWorkDirectoryURL
      .appending(path: "Sources")
  }

  func cachedClasspathFile(swiftModule: String) -> URL {
    self.pluginWorkDirectoryURL
      .appending(path: "\(swiftModule)", directoryHint: .notDirectory)
  }
}

func getJavaHomeFromSDKMAN() -> String? {
  let home = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".sdkman/candidates/java/current")

  let javaBin = home.appendingPathComponent("bin/java").path
  if FileManager.default.isExecutableFile(atPath: javaBin) {
    return home.path
  }
  return nil
}

func getJavaHomeFromPath() -> String? {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
  task.arguments = ["java"]

  let pipe = Pipe()
  task.standardOutput = pipe

  do {
    try task.run()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else { return nil }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard
      let javaPath = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !javaPath.isEmpty
    else { return nil }

    let resolved = URL(fileURLWithPath: javaPath).resolvingSymlinksInPath()
    return
      resolved
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .path
  } catch {
    return nil
  }
}
