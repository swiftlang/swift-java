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

import ArgumentParser
import SwiftJava
import SwiftJavaJNICore

@JavaClass("com.example.swift.SwiftArgumentParserMain")
open class SwiftArgumentParserMain: JavaObject {
}

/// Lets tests call the Java `static native` entry point, which dispatches back
/// into the Swift implementation below
extension JavaClass<SwiftArgumentParserMain> {
  @JavaStaticMethod
  public func runSwiftMain(_ args: [String]) -> String
}

/// Describes the Java `native` methods of ``SwiftArgumentParserMain``.
protocol SwiftArgumentParserMainNativeMethods {
  static func runSwiftMain(_ args: [String], environment: JNIEnvironment) -> String
}

// snippet.argumentParserImplementation
/// The command that the Java entry point delegates its arguments to.
struct HelloCommand: ParsableCommand {
  @Flag(name: .shortAndLong, help: "Enable verbose output")
  var verbose: Bool = false

  @Argument(help: "Who to greet")
  var name: String = "world"

  func greeting() -> String {
    verbose ? "Hello, \(name)! (verbose)" : "Hello, \(name)!"
  }
}

@JavaImplementation("com.example.swift.SwiftArgumentParserMain")
extension SwiftArgumentParserMain: SwiftArgumentParserMainNativeMethods {
  @JavaMethod
  static func runSwiftMain(_ args: [String], environment: JNIEnvironment) -> String {
    do {
      return try HelloCommand.parse(args).greeting()
    } catch {
      return HelloCommand.fullMessage(for: error)
    }
  }
}
// snippet.end
