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
import SwiftJavaConfigurationShared

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

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    try await JavaResolver.runResolveCommand(
      config: &config,
      input: input,
      swiftModule: swiftModule,
      outputDirectory: commonOptions.outputDirectory
    )
  }

  public func artifactIDAsModuleID(_ artifactID: String) -> String {
    let components = artifactID.split(whereSeparator: { $0 == "-" })
    let camelCased = components.map { $0.capitalized }.joined()
    return camelCased
  }
}

