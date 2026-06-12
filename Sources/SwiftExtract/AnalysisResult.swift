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

/// The complete analysis result of the analyzed Swift inputs.
/// This is used as the primary input to source generators, which then act on the analyzed decls.
public struct AnalysisResult {
  public var extractedTypes: [String: ExtractedNominalType]
  public var extractedGlobalVariables: [ExtractedFunc]
  public var extractedGlobalFuncs: [ExtractedFunc]

  public init(
    extractedTypes: [String: ExtractedNominalType],
    extractedGlobalVariables: [ExtractedFunc],
    extractedGlobalFuncs: [ExtractedFunc]
  ) {
    self.extractedTypes = extractedTypes
    self.extractedGlobalVariables = extractedGlobalVariables
    self.extractedGlobalFuncs = extractedGlobalFuncs
  }
}
