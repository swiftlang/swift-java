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

/// JVM class file constant pool tags (JVM Spec §4.4).
enum JavaConstantPoolTag: UInt8 {
  case utf8 = 1
  case integer = 3
  case float = 4
  case long = 5
  case double = 6
  case `class` = 7
  case string = 8
  case fieldref = 9
  case methodref = 10
  case interfaceMethodref = 11
  case nameAndType = 12
  case methodHandle = 15
  case methodType = 16
  case dynamic = 17
  case invokeDynamic = 18
  case module = 19
  case package = 20
}
