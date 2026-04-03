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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct Data: DataProtocol {
  public init(bytes: UnsafeRawPointer, count: Int)
  public init(_ bytes: [UInt8])
  public var count: Int { get }
  public func withUnsafeBytes(_ body: (UnsafeRawBufferPointer) -> Void)
}
