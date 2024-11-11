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

public class MySwiftClass {

  public var len: Int
  public var cap: Int

  public init(len: Int, cap: Int) {
    self.len = len
    self.cap = cap

    p("\(MySwiftClass.self).len = \(self.len)")
    p("\(MySwiftClass.self).cap = \(self.cap)")
    let addr = unsafeBitCast(self, to: UInt64.self)
    p("initializer done, self = 0x\(String(addr, radix: 16, uppercase: true))")
  }

  deinit {
    let addr = unsafeBitCast(self, to: UInt64.self)
    p("Deinit, self = 0x\(String(addr, radix: 16, uppercase: true))")
  }

  public var counter: Int32 = 0

  public func voidMethod() {
    p("")
  }

  public func takeIntMethod(i: Int) {
    p("i:\(i)")
  }

  public func echoIntMethod(i: Int) -> Int {
    p("i:\(i)")
    return i
  }

  public func makeIntMethod() -> Int {
    p("make int -> 12")
    return 12
  }

  public func makeRandomIntMethod() -> Int {
    return Int.random(in: 1..<256)
  }
}

// ==== Internal helpers

private func p(_ msg: String, file: String = #fileID, line: UInt = #line, function: String = #function) {
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
