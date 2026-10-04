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

import SwiftJavaJNICore

/// A common protocol for Java collection and iterable types that can be iterated as a Swift `Sequence`.
public protocol JavaCollectionProtocol: Sequence where Iterator == JavaIterator<Element> {
  associatedtype Element: AnyJavaObject

  /// Returns a Java iterator over the elements in this collection.
  func iterator() -> JavaIterator<Element>!
}

extension JavaCollectionProtocol {
  public func makeIterator() -> JavaIterator<Element> {
    self.iterator()
  }
}
