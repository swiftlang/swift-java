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
import Java2SwiftLib
import JExtractSwift
import JavaKit
import JavaKitJar
import JavaKitNetwork
import JavaKitReflection
import SwiftSyntax
import SwiftSyntaxBuilder
import JavaKitConfigurationShared
import JavaKitShared

@main
struct SwiftJavaMain: AsyncParsableCommand {
  static var _commandName: String { "swift-java" }

    static var configuration = CommandConfiguration(
        abstract: "A utility for Swift and Java interoperability.",
        subcommands: [
          JavaToSwift.self,
          SwiftToJava.self,
         ],
        defaultSubcommand: JavaToSwift.self
    )
}

