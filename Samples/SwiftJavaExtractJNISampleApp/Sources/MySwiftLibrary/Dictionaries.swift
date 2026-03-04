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

public func makeStringToLongDictionary() -> [String: Int64] {
  ["hello": 1, "world": 2]
}

public func stringToLongDictionary(dict: [String: Int64]) -> [String: Int64] {
  dict
}
