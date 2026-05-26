//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Build a single `--depends-on` argument pair: `["--depends-on", "<value>"]`.
///
/// Value form: `[<ModuleName>=]<configPath>[,<sourcePath>...]`.
func makeDependsOnArgument(
  moduleName: String? = nil,
  configPath: String,
  sourcePaths: [String] = []
) -> [String] {
  var value: String
  if let moduleName, !moduleName.isEmpty {
    value = "\(moduleName)=\(configPath)"
  } else {
    value = configPath
  }
  if !sourcePaths.isEmpty {
    value += "," + sourcePaths.joined(separator: ",")
  }
  return ["--depends-on", value]
}
