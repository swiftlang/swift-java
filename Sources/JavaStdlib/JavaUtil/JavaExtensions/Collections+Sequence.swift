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

import SwiftJava

extension ArrayList: JavaCollectionProtocol {
  public typealias Element = E
}

extension ArrayDeque: JavaCollectionProtocol {
  public typealias Element = E
}

extension HashSet: JavaCollectionProtocol {
  public typealias Element = E
}

extension TreeSet: JavaCollectionProtocol {
  public typealias Element = E
}

extension PriorityQueue: JavaCollectionProtocol {
  public typealias Element = E
}

extension Queue: JavaCollectionProtocol {
  public typealias Element = E
}
