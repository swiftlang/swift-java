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

public var globalVariable: Int64 = 0

public func helloWorld() {
  p("\(#function)")
}

public func globalTakeInt(i: Int64) {
  p("i:\(i)")
}

public func globalMakeInt() -> Int64 {
  return 42
}

public func globalWriteString(string: String) -> Int64 {
  return Int64(string.count)
}

public func globalTakeIntInt(i: Int64, j: Int64) {
  p("i:\(i), j:\(j)")
}

public func echoUnsignedInt(i: UInt32, j: UInt64) -> UInt64 {
  p("i:\(i), j:\(j)")
  return UInt64(i) + j
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
