//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Subprocess
import SwiftIfConfig

@main struct StaticBuildConfigPluginExecutable {
  static func main() async throws {
    let args = CommandLine.arguments
    guard args.count > 1 else {
      print("Usage: \(args[0]) <destination_path>")
      return
    }
    let dst = URL(fileURLWithPath: args[1])

    let data = try await loadStaticBuildConfig()
    let template = #"""
      import Foundation
      import SwiftIfConfig

      extension StaticBuildConfiguration {
        static var embedded: Data {
          Data(#"\#(data)"#.utf8)
        }
      }
      """#
    try template.write(to: dst, atomically: true, encoding: .utf8)
  }

  static func loadStaticBuildConfig() async throws -> String {
    #if compiler(>=6.3)
    let result = try await run(
      .name("swift"),
      arguments: ["frontend", "-print-static-build-config", "-target", "aarch64-unknown-linux-gnu"],
      output: .string(limit: 65536),
      error: .string(limit: 65536)
    )
    if let error = result.standardError, !error.isEmpty {
      fatalError(error)
    }
    return result.standardOutput ?? ""
    #else
    #if compiler(>=6.2)
    let configuration = StaticBuildConfiguration(
      languageVersion: .init(components: [5, 10]),
      compilerVersion: .init(components: [6, 2])
    )
    #else
    let configuration = StaticBuildConfiguration(
      languageVersion: .init(components: [5, 10]),
      compilerVersion: .init(components: [6, 1])
    )
    #endif
    let encoder = JSONEncoder()
    return String(data: try encoder.encode(configuration), encoding: .utf8) ?? ""
    #endif
  }
}
