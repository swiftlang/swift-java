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

// This is a "plain Swift" file containing various types of declarations,
// that is exported to Java by using the `jextract-swift` tool.
//
// No annotations are necessary on the Swift side to perform the export.

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public func helloWorld() {
}

public func globalTakeInt(i: Int) {
}

public func globalTakeIntInt(i: Int, j: Int) {
}

public func globalCallMeRunnable(run: () -> Void) {
  run()
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

public func globalCallMeDoubleUnaryOperator(run: (Double) -> Double) -> Double {
  run(1.0)
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

public func globalCallMeDoubleToIntFunction(run: (Double) -> Int32) -> Int32 {
  run(1.0)
}

public func globalCallMeLongToIntFunction(run: (Int64) -> Int32) -> Int32 {
  run(1)
}

public func globalCallMeDoubleToLongFunction(run: (Double) -> Int64) -> Int64 {
  run(1.0)
}

public func globalCallMeIntToLongFunction(run: (Int32) -> Int64) -> Int64 {
  run(1)
}

// ==== Internal helpers

func p(_ msg: String, file: String = #fileID, line: UInt = #line, function: String = #function) {
  print("[swift][\(file):\(line)](\(function)) \(msg)")
  fflush(stdout)
}
