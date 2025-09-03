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
#elseif os(Android)
import Android
#else
import Darwin.C
#endif

import Foundation

public func helloWorld() {
  p("\(#function)")
}

public func globalTakeInt(i: Int) {
  p("i:\(i)")
}

public func globalMakeInt() -> Int {
  return 42
}

public func globalWriteString(string: String) -> Int {
  return string.count
}

public func globalTakeIntInt(i: Int, j: Int) {
  p("i:\(i), j:\(j)")
}

public func globalCallMeRunnable(run: () -> ()) {
  run()
}

public func globalReceiveRawBuffer(buf: UnsafeRawBufferPointer) -> Int {
  return buf.count
}

public var globalBuffer: UnsafeRawBufferPointer = UnsafeRawBufferPointer(UnsafeMutableRawBufferPointer.allocate(byteCount: 124, alignment: 1))

public func globalReceiveReturnData(data: Data) -> Data {
  return Data(data)
}

public func withBuffer(body: (UnsafeRawBufferPointer) -> Void) {
  body(globalBuffer)
}

public func globalReceiveSomeDataProtocol(data: some DataProtocol) -> Int {
  p(Array(data).description)
  return data.count
}

public func globalReceiveOptional(o1: Int?, o2: (some DataProtocol)?) -> Int {
  switch (o1, o2) {
  case (nil, nil):
    p("<nil>, <nil>")
    return 0
  case (let v1?, nil):
    p("\(v1), <nil>")
    return 1
  case (nil, let v2?):
    p("<nil>, \(v2)")
    return 2
  case (let v1?, let v2?):
    p("\(v1), \(v2)")
    return 3
  }
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
