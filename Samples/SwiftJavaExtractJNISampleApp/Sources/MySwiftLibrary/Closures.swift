//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// snippet.closureDefinition
public func emptyClosure(closure: () -> Void) {
  closure()
}

public func closureWithInt(input: Int64, closure: (Int64) -> Int64) -> Int64 {
  closure(input)
}

public func globalCallMeBooleanSupplier(run: () -> Bool) -> Bool {
  run()
}

public func globalCallMeIntSupplier(run: () -> Int32) -> Int32 {
  run()
}

public func globalCallMeLongSupplier(run: () -> Int64) -> Int64 {
  run()
}

public func globalCallMeDoubleSupplier(run: () -> Double) -> Double {
  run()
}

public func globalCallMeIntConsumer(run: (Int32) -> Void) {
  run(1)
}

public func globalCallMeLongConsumer(run: (Int64) -> Void) {
  run(1)
}

public func globalCallMeDoubleConsumer(run: (Double) -> Void) {
  run(1.0)
}

public func globalCallMeIntPredicate(run: (Int32) -> Bool) -> Bool {
  run(1)
}

public func globalCallMeLongPredicate(run: (Int64) -> Bool) -> Bool {
  run(1)
}

public func globalCallMeDoublePredicate(run: (Double) -> Bool) -> Bool {
  run(1.0)
}

public func globalCallMeIntUnaryOperator(run: (Int32) -> Int32) -> Int32 {
  run(1)
}

public func globalCallMeLongUnaryOperator(run: (Int64) -> Int64) -> Int64 {
  run(1)
}

public func globalCallMeIntBinaryOperator(run: (Int32, Int32) -> Int32) -> Int32 {
  run(1, 2)
}

public func globalCallMeLongBinaryOperator(run: (Int64, Int64) -> Int64) -> Int64 {
  run(1, 2)
}

public func globalCallMeDoubleBinaryOperator(run: (Double, Double) -> Double) -> Double {
  run(1.0, 2.0)
}

public func closureMultipleArguments(
  input1: Int64,
  input2: Int64,
  closure: (Int64, Int64) -> Int64
) -> Int64 {
  closure(input1, input2)
}
// snippet.end
