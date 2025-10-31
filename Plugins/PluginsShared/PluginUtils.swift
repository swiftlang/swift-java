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

extension String {
  var kebabCased: String {
    var result = ""

    for (index, char) in input.enumerated() {
      if char.isUppercase {
        if index != 0 {
          result.append("-")
        }
        result.append(char.lowercased())
      } else {
        result.append(char)
      }
    }

    return result
  }
}
