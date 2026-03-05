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

public struct BasicStruct {
    public var value: Int
    public init(value: Int) {
        self.value = value
    }
}

public struct GenericStruct<T> {
    public var value: Int
    public init(value: Int) {
        self.value = value
    }
}

public func makeGenericStruct(value: Int) -> GenericStruct<Int> {
    return GenericStruct(value: value)
}
