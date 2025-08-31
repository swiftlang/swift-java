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

public func helloWorld() {
  p("\(#function)")
}

public func globalTakeInt(i: Int) {
  p("i:\(i)")
}

public func globalTakeIntInt(i: Int, j: Int) {
  p("i:\(i), j:\(j)")
}

public func globalCallMeRunnable(run: () -> ()) {
  run()
}

// ==== Internal helpers

func p(_ msg: String, file: String = #fileID, line: UInt = #line, function: String = #function) {
  print("[swift][\(file):\(line)](\(function)) \(msg)")
  fflush(stdout)
}

