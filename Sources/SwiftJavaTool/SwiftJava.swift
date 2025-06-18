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
import SwiftJavaLib
import JExtractSwiftLib
import JavaKit
import JavaKitJar
import JavaKitNetwork
import JavaKitReflection
import SwiftSyntax
import SwiftSyntaxBuilder
import JavaKitConfigurationShared
import JavaKitShared

/// Command-line utility to drive the export of Java classes into Swift types.
@main
struct SwiftJava: SwiftJavaBaseAsyncParsableCommand, HasCommonJVMOptions { // FIXME: this is just a normal async command, no parsing happening here
  static var _commandName: String { "swift-java" }

  static let configuration = CommandConfiguration(
    abstract: "Generate sources and configuration for Swift and Java interoperability.",
    subcommands: [
      ConfigureCommand.self,
      ResolveCommand.self,
      WrapJavaCommand.self,
      JExtractCommand.self
    ])

  var effectiveSwiftModule: String {
    if let module = self.outputSwift?.split(separator: "/").last {
      String(module)
    } else {
      "UnknownSwiftModule"
    }
  }

  @Option(help: "The directory where generated Swift files should be written. Generally used with jextract mode.")
  var outputSwift: String? = nil

  @Option(help: "The directory where generated Java files should be written. Generally used with jextract mode.")
  var outputJava: String? = nil

  @OptionGroup var commonOptions: SwiftJava.CommonOptions
  @OptionGroup var commonJVMOptions: SwiftJava.CommonJVMOptions

//  @Argument(
//    help: "The input file, which is either a Java2Swift configuration file or (if '-jar' was specified) a Jar file."
//  )
  var input: String? // FIXME: top level command cannot have input argument like this

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    guard CommandLine.arguments.count >= 2 else {
      // there's no "default" command, print USAGE when no arguments/parameters are passed.
      print("error: Must specify mode subcommand (e.g. configure, resolve, jextract, ...).\n\n\(Self.helpMessage())")
      return
    }

    // TODO: some options are exclusive to each other so we should detect that
    if let inputSwift = commonOptions.inputSwift {
      guard let inputSwift = commonOptions.inputSwift else {
        print("[swift-java] --input-swift enabled 'jextract' mode, however no --output-swift directory was provided!\n\(Self.helpMessage())")
        return
      }
      guard let outputSwift else {
        print("[swift-java] --output-swift enabled 'jextract' mode, however no --output-swift directory was provided!\n\(Self.helpMessage())")
        return
      }
      guard let outputJava else {
        print("[swift-java] --output-java enabled 'jextract' mode, however no --output-java directory was provided!\n\(Self.helpMessage())")
        return
      }
      config.swiftModule = self.effectiveSwiftModule
      config.inputSwiftDirectory = inputSwift
      config.outputSwiftDirectory = outputSwift
      config.outputJavaDirectory = outputJava
    }

    print("[debug][swift-java] Running swift-java in mode: " + "jextract (legacy, to be moved into subcommand)")

    try jextractSwift(config: config)
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
  case badConfigOption(String)
}

extension JavaToSwiftError: CustomStringConvertible {
  var description: String {
    switch self {
    case .badConfigOption(_):
      "configuration option must be of the form '<swift module name>=<path to config file>"
    }
  }
}

