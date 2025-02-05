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

/// Describes a tag type in C, which is either a struct or an enum.
public enum CTag {
  case `struct`(CStruct)
  case `enum`(CEnum)
  case `union`(CUnion)

  public var name: String {
    switch self {
      case .struct(let cStruct): return cStruct.name
      case .enum(let cEnum): return cEnum.name
      case .union(let cUnion): return cUnion.name
    }
  }
}

