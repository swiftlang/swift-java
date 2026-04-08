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
import PackagePlugin

@main
struct _StaticBuildConfigPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
    let executable = try context.tool(named: "StaticBuildConfigPluginExecutable").url
    let out = context.pluginWorkDirectoryURL.appending(path: "static-build-config.json")
    return [
      .buildCommand(
        displayName: "Run -print-static-build-config",
        executable: executable,
        arguments: [out.path(percentEncoded: false)],
        environment: [:],
        inputFiles: [],
        outputFiles: [out]
      )
    ]
  }
}
