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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public func echoData(_ data: Data) -> Data {
  data
}

public func makeData() -> Data {
  Data([0x01, 0x02, 0x03, 0x04])
}

public func getDataCount(_ data: Data) -> Int {
  data.count
}

public func compareData(_ data1: Data, _ data2: Data) -> Bool {
  data1 == data2
}
