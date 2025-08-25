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
import ArgumentParser
import SwiftJavaToolLib
import SwiftJava
import JavaUtilJar
import SwiftJavaToolLib
import JExtractSwiftLib
import SwiftJavaConfigurationShared

/// Extract Java bindings from Swift sources or interface files.
///
/// Example usage:
/// ```
/// > swift-java jextract
//      --input-swift Sources/SwiftyBusiness \
///     --output-swift .build/.../outputs/SwiftyBusiness \
///     --output-Java .build/.../outputs/Java
/// ```
extension SwiftJava {

  struct JExtractCommand: SwiftJavaBaseAsyncParsableCommand, HasCommonOptions {
    static let configuration = CommandConfiguration(
      commandName: "jextract", // TODO: wrap-swift?
      abstract: "Wrap Swift functions and types with Java bindings, making them available to be called from Java")

    @OptionGroup var commonOptions: SwiftJava.CommonOptions

    @Option(help: "The mode of generation to use for the output files. Used with jextract mode.")
    var mode: JExtractGenerationMode = .ffm

    @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
    var swiftModule: String

    var effectiveSwiftModule: String {
      swiftModule
    }

    @Option(help: "The Java package the generated Java code should be emitted into.")
    var javaPackage: String? = nil

    @Option(help: "The directory where generated Swift files should be written. Generally used with jextract mode.")
    var outputSwift: String

    @Option(help: "The directory where generated Java files should be written. Generally used with jextract mode.")
    var outputJava: String

    @Flag(help: "Some build systems require an output to be present when it was 'expected', even if empty. This is used by the JExtractSwiftPlugin build plugin, but otherwise should not be necessary.")
    var writeEmptyFiles: Bool = false

    @Option(help: "The mode of generation to use for the output files. Used with jextract mode. By default, unsigned Swift types are imported as their bit-width compatible signed Java counterparts, and annotated using the '@Unsigned' annotation. You may choose the 'wrap-guava' mode in order to import types as class wrapper types (`UnsignedInteger` et al) defined by the Google Guava library's `com.google.common.primitives' package. that ensure complete type-safety with regards to unsigned values, however they incur an allocation and performance overhead.")
    var unsignedNumbers: JExtractUnsignedIntegerMode = .default

    @Option(help: "The lowest access level of Swift declarations that should be extracted, defaults to 'public'.")
    var minimumInputAccessLevel: JExtractMinimumAccessLevelMode = .default

    @Option(help: "The memory management mode to use for the generated code. By default, the user must explicitly provide `SwiftArena` to all calls that require it. By choosing `allow-automatic`, user can omit this parameter and a global GC-based arena will be used. `force-automatic` removes all explicit memory management.")
    var memoryManagementMode: JExtractMemoryManagementMode = .default

    @Option(
      help: """
            A swift-java configuration file for a given Swift module name on which this module depends,
            e.g., Sources/JavaJar/swift-java.config. There should be one of these options
            for each Swift module that this module depends on (transitively) that contains wrapped Java sources.
            """
    )
    var dependsOn: [String] = []
  }
}

extension SwiftJava.JExtractCommand {
  func runSwiftJavaCommand(config: inout Configuration) async throws {
    if let javaPackage {
      config.javaPackage = javaPackage
    }
    config.swiftModule = self.effectiveSwiftModule
    config.outputJavaDirectory = outputJava
    config.outputSwiftDirectory = outputSwift
    config.writeEmptyFiles = writeEmptyFiles
    config.unsignedNumbersMode = unsignedNumbers
    config.minimumInputAccessLevelMode = minimumInputAccessLevel
    config.memoryManagementMode = memoryManagementMode

    try checkModeCompatibility()

    if let inputSwift = commonOptions.inputSwift {
      config.inputSwiftDirectory = inputSwift
    } else if let swiftModule = config.swiftModule {
      // This is a "good guess" technically a target can be somewhere else, but then you can use --input-swift
      config.inputSwiftDirectory = "\(FileManager.default.currentDirectoryPath)/Sources/\(swiftModule)"
    }

    print("[debug][swift-java] Running 'swift-java jextract' in mode: " + "\(self.mode)".bold)

    // Load all of the dependent configurations and associate them with Swift modules.
    let dependentConfigs = try loadDependentConfigs(dependsOn: self.dependsOn)
    print("[debug][swift-java] Dependent configs: \(dependentConfigs.count)")

    try jextractSwift(config: config, dependentConfigs: dependentConfigs.map(\.1))
  }

  /// Check if the configured modes are compatible, and fail if not
  func checkModeCompatibility() throws {
    if self.mode == .jni {
      switch self.unsignedNumbers {
      case .annotate:
        throw IllegalModeCombinationError("JNI mode does not support '\(JExtractUnsignedIntegerMode.wrapGuava)' Unsigned integer mode! \(Self.helpMessage)")
      case .wrapGuava:
        () // OK
      }
    } else if self.mode == .ffm {
      guard self.memoryManagementMode == .explicit else {
        throw IllegalModeCombinationError("FFM mode does not support '\(self.memoryManagementMode)' memory management mode! \(Self.helpMessage)")
      }
    }
  }
}

struct IncompatibleModeError: Error {
  let message: String
  init(_ message: String) {
    self.message = message
  }
}

extension SwiftJava.JExtractCommand {
  func jextractSwift(
    config: Configuration,
    dependentConfigs: [Configuration]
  ) throws {
    try SwiftToJava(config: config, dependentConfigs: dependentConfigs).run()
  }

}

struct IllegalModeCombinationError: Error {
  let message: String
  init(_ message: String) {
    self.message = message
  }
}

extension JExtractGenerationMode: ExpressibleByArgument {}
extension JExtractUnsignedIntegerMode: ExpressibleByArgument {}
extension JExtractMinimumAccessLevelMode: ExpressibleByArgument {}
extension JExtractMemoryManagementMode: ExpressibleByArgument {}
