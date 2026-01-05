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

/// Detected JAVA_HOME for this process.
package let javaHome: String = findJavaHome()

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
public func findJavaHome() -> String {
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

  if let home = getJavaHomeFromLibexecJavaHome(),
    !home.isEmpty
  {
    return home
  }

  if let home = getJavaHomeFromSDKMAN() {
    return home
  }

  if let home = getJavaHomeFromPath() {
    return home
  }


  if ProcessInfo.processInfo.environment["SPI_PROCESSING"] == "1"
    && ProcessInfo.processInfo.environment["SPI_BUILD"] == nil
  {
    // Just ignore that we're missing a JAVA_HOME when building in Swift Package Index during general processing where no Java is needed. However, do _not_ suppress the error during SPI's compatibility build stage where Java is required.
    return ""
  }
  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}

/// On MacOS we can use the java_home tool as a fallback if we can't find JAVA_HOME environment variable.
public func getJavaHomeFromLibexecJavaHome() -> String? {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")

  // Check if the executable exists before trying to run it
  guard FileManager.default.fileExists(atPath: task.executableURL!.path) else {
    print("/usr/libexec/java_home does not exist")
    return nil
  }

  let pipe = Pipe()
  task.standardOutput = pipe
  task.standardError = pipe  // Redirect standard error to the same pipe for simplicity

  do {
    try task.run()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
      in: .whitespacesAndNewlines)

    if task.terminationStatus == 0 {
      return output
    } else {
      print("java_home terminated with status: \(task.terminationStatus)")
      // Optionally, log the error output for debugging
      if let errorOutput = String(
        data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
        print("Error output: \(errorOutput)")
      }
      return nil
    }
  } catch {
    print("Error running java_home: \(error)")
    return nil
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
    guard let javaPath = String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !javaPath.isEmpty
    else { return nil }

    let resolved = URL(fileURLWithPath: javaPath).resolvingSymlinksInPath()
    return resolved
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .path
  } catch {
    return nil
  }
}
