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
import Foundation
import SwiftJavaToolLib
import JExtractSwiftLib
import SwiftJava
import JavaUtilJar
import JavaNet
import JavaLangReflect
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftJavaConfigurationShared
import SwiftJavaShared

/// Command-line utility to drive the export of Java classes into Swift types.
@main
struct SwiftJava: AsyncParsableCommand {
  static var _commandName: String { "swift-java" }

  static let configuration = CommandConfiguration(
    abstract: "Generate sources and configuration for Swift and Java interoperability.",
    subcommands: [
      ConfigureCommand.self,
      ResolveCommand.self,
      WrapJavaCommand.self,
      JExtractCommand.self
    ])

  public static func main() async {
    do {
      var command = try parseAsRoot(nil)
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      print("Invocation: \(CommandLine.arguments.joined(separator: " "))")
      exit(withError: error)
    }
  }

  mutating func run() async throws {
    guard CommandLine.arguments.count >= 2 else {
      // there's no "default" command, print USAGE when no arguments/parameters are passed.
      print("error: Must specify mode subcommand (e.g. configure, resolve, jextract, ...).\n\n\(Self.helpMessage())")
      return
    }

    print("error: Must specify subcommand to execute.\n\n\(Self.helpMessage())")
    return
  }

  private func names(from javaClassNameOpt: String) -> (javaClassName: String, swiftName: String) {
    let javaClassName: String
    let swiftName: String
    if let equalLoc = javaClassNameOpt.firstIndex(of: "=") {
      let afterEqual = javaClassNameOpt.index(after: equalLoc)
      javaClassName = String(javaClassNameOpt[..<equalLoc])
      swiftName = String(javaClassNameOpt[afterEqual...])
    } else {
      if let dotLoc = javaClassNameOpt.lastIndex(of: ".") {
        let afterDot = javaClassNameOpt.index(after: dotLoc)
        swiftName = String(javaClassNameOpt[afterDot...])
      } else {
        swiftName = javaClassNameOpt
      }

      javaClassName = javaClassNameOpt
    }

    return (javaClassName, swiftName.javaClassNameToCanonicalName)
  }

}

enum JavaToSwiftError: Error {
  case badConfigOption
}

extension JavaToSwiftError: CustomStringConvertible {
  var description: String {
    switch self {
    case .badConfigOption:
      "configuration option must be of the form '<swift module name>=<path to config file>"
    }
  }
}

