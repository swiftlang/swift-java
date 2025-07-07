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

import SwiftSyntax

/// Scan importing modules.
func importingModuleNames(sourceFile: SourceFileSyntax) -> [String] {
  var importingModuleNames: [String] = []
  for item in sourceFile.statements {
    if let importDecl = item.item.as(ImportDeclSyntax.self) {
      guard let moduleName = importDecl.path.first?.name.text else {
        continue
      }
      importingModuleNames.append(moduleName)
    }
  }
  return importingModuleNames
}
