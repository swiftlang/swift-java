//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import MySwiftDependencyLibrary

// Show using a type from another module
// This depends on --depends-on being passed correctly
public func consumeValueFromOtherModule(_ v: ValueInDependencyModule) -> Int32 {
  v.value + 1
}
