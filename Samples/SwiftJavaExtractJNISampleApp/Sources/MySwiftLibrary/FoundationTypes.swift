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

public func compareDates(date1: Date, date2: Date) -> Bool {
  date1 == date2
}

public func dateFromSeconds(_ seconds: Double) -> Date {
  Date(timeIntervalSince1970: seconds)
}

public func echoUUID(_ uuid: UUID) -> UUID {
  uuid
}

public func makeUUID() -> UUID {
  UUID()
}

// snippet.foundationURLDefinition
public func echoURL(_ url: URL) -> URL {
  url
}
// snippet.end
