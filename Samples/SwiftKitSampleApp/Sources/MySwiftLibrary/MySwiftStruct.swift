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

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public struct MySwiftStruct {
    private var numberA: Int
    private var numberB: Int
    private var numberC: Int
    private var numberD: Int

    public init(number: Int) {
        self.numberA = number
        self.numberB = number
        self.numberC = number
        self.numberD = number
    }

    public func getTheNumber() -> Int {
        numberA
    }
}

public struct MyHugeSwiftStruct {
    private var numberA: Int
    private var numberB: Int
    private var numberC: Int
    private var numberD: Int

    private var numberA2: Int = 0
    private var numberB2: Int = 0
    private var numberC2: Int = 0
    private var numberD2: Int = 0

    public init(number: Int) {
        self.numberA = number
        self.numberB = number
        self.numberC = number
        self.numberD = number
    }

    public func getTheNumber() -> Int {
        numberA
    }
}
