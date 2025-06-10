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

struct AnalysisResult {
  let importedTypes: [String: ImportedNominalType]
  let importedGlobalVariables: [ImportedFunc]
  let importedGlobalFuncs: [ImportedFunc]
}
