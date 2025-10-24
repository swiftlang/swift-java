//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// This file exists to exercise the swiftpm plugin generating separate output Java files 
// for the public types; because Java public types must be in a file with the same name as the type.

public struct PublicTypeOne {
  public init() {}
  public func test() {}
}

public struct PublicTypeTwo { 
  public init() {}
  public func test() {}
}