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

import Foundation

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public func helloWorld() {
}

public func globalTakeInt(i: Int) {
}

public func globalMakeInt() -> Int {
  42
}

public func globalWriteString(string: String) -> Int {
  string.count
}

public func globalTakeIntInt(i: Int, j: Int) {
}

public func globalCallMeRunnable(run: () -> Void) {
  run()
}

public func globalReceiveRawBuffer(buf: UnsafeRawBufferPointer) -> Int {
  buf.count
}

public var globalBuffer: UnsafeRawBufferPointer = UnsafeRawBufferPointer(
  UnsafeMutableRawBufferPointer.allocate(byteCount: 124, alignment: 1)
)

public func globalReceiveReturnData(data: Data) -> Data {
  Data(data)
}

public func withBuffer(body: (UnsafeRawBufferPointer) -> Void) {
  body(globalBuffer)
}

public func getArray() -> [UInt8] {
  [1, 2, 3]
}

// Tuple round-trips for jextract FFM (see `FFMTupleTest` in the sample app).
public func ffmTupleReturnPair() -> (Int32, Int64) {
  (42, 43)
}

public func ffmTupleSumPair(_ arg: (Int32, Int64)) -> Int64 {
  Int64(arg.0) + arg.1
}

public func ffmTupleLabeledPair() -> (x: Int32, y: Int32) {
  (x: 10, y: 20)
}

public func sumAllByteArrayElements(actuallyAnArray: UnsafeRawPointer, count: Int) -> Int {
  let bufferPointer = UnsafeRawBufferPointer(start: actuallyAnArray, count: count)
  let array = Array(bufferPointer)
  return Int(array.reduce(0, { partialResult, element in partialResult + element }))
}

public func sumAllByteArrayElements(array: [UInt8]) -> Int {
  Int(array.reduce(0, { partialResult, element in partialResult + element }))
}
public func returnSwiftArray() -> [UInt8] {
  [1, 2, 3, 4]
}

public func withArray(body: ([UInt8]) -> Void) {
  body([1, 2, 3])
}

public func globalReceiveSomeDataProtocol(data: some DataProtocol) -> Int {
  p(Array(data).description)
  return data.count
}

public func globalReceiveOptional(o1: Int?, o2: (some DataProtocol)?) -> Int {
  switch (o1, o2) {
  case (nil, nil):
    return 0
  case (let v1?, nil):
    return 1
  case (nil, let v2?):
    return 2
  case (let v1?, let v2?):
    return 3
  }
}

// ==== -----------------------------------------------------------------------
// MARK: String returns

public func globalMakeString() -> String {
  "Hello from Swift!"
}

public func globalStringIdentity(string: String) -> String {
  string
}

// ==== -----------------------------------------------------------------------
// MARK: Throwing functions

public struct SwiftExampleError: Error {
  public let message: String
}

public func globalThrowingVoid(doThrow: Bool) throws {
  if doThrow {
    throw SwiftExampleError(message: "expected error in globalThrowingVoid")
  }
}

public func globalThrowingReturn(doThrow: Bool) throws -> Int {
  if doThrow {
    throw SwiftExampleError(message: "expected error in globalThrowingReturn")
  }
  return 42
}

public func globalThrowingString(doThrow: Bool) throws -> String {
  if doThrow {
    throw SwiftExampleError(message: "expected error in globalThrowingString")
  }
  return "Hello from throwing Swift!"
}

// ==== -----------------------------------------------------------------------
// MARK: Overloaded functions

public func globalOverloaded(a: Int) {
  p("globalOverloaded(a: \(a))")
}

public func globalOverloaded(b: Int) {
  p("globalOverloaded(b: \(b))")
}

// ==== Internal helpers

func p(_ msg: String, file: String = #fileID, line: UInt = #line, function: String = #function) {
  print("[swift][\(file):\(line)](\(function)) \(msg)")
  fflush(stdout)
}

#if os(Linux)
// FIXME: why do we need this workaround?
@_silgen_name("_objc_autoreleaseReturnValue")
public func _objc_autoreleaseReturnValue(a: Any) {}

@_silgen_name("objc_autoreleaseReturnValue")
public func objc_autoreleaseReturnValue(a: Any) {}
#endif
