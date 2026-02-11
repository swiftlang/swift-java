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

struct ImportedSwiftModule: Hashable {
  let name: String
  let availableWithModuleName: String?
  var alternativeModuleNames: Set<String>
  var isMainSourceOfSymbols: Bool

  init(
    name: String,
    availableWithModuleName: String? = nil,
    alternativeModuleNames: Set<String> = [],
    isMainSourceOfSymbols: Bool = false
  ) {
    self.name = name
    self.availableWithModuleName = availableWithModuleName
    self.alternativeModuleNames = alternativeModuleNames
    self.isMainSourceOfSymbols = isMainSourceOfSymbols
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.name == rhs.name
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }
}
