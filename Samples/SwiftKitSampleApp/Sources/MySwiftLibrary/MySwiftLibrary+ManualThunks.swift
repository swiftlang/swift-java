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

import SwiftKitSwift

@_cdecl("swiftjava_manual_getArrayMySwiftClass")
public func swiftjava_manual_getArrayMySwiftClass() -> UnsafeMutableRawPointer /* [MySwiftClass] */ {
  p("[thunk] swiftjava_manual_getArrayMySwiftClass")
  var array: [MySwiftClass] = getArrayMySwiftClass()
  p("[thunk] swiftjava_manual_getArrayMySwiftClass -> \(array)")
  // TODO: we need to retain it I guess as we escape it into Java
  var ptr: UnsafeRawBufferPointer!
  array.withUnsafeBytes {
    ptr = $0
  }
  p("[thunk] swiftjava_manual_getArrayMySwiftClass -> \(ptr)")

  return UnsafeMutableRawPointer(mutating: ptr!.baseAddress)!
}

@_cdecl("swiftjava_SwiftKitSwift_Array_count") // FIXME: hardcoded for MySwiftClass
public func swiftjava_SwiftKitSwift_Array_count(
  rawPointer: UnsafeMutableRawPointer, // Array<T>
  elementType: UnsafeMutableRawPointer // Metadata of T
) -> Int {
  print("[swift][\(#fileID):\(#line)](\(#function) passed in rawPointer = \(rawPointer)")
  print("[swift][\(#fileID):\(#line)](\(#function) passed in metadata = \(elementType)")

  let array = rawPointer.assumingMemoryBound(to: [MySwiftClass].self)
  .pointee

  print("[swift][\(#fileID):\(#line)](\(#function) ARRAY count = \(array.count)")
  print("[swift][\(#fileID):\(#line)](\(#function) ARRAY[0] = \(unsafeBitCast(array[0], to: UInt64.self))")
  return array.count
}

@_cdecl("swiftjava_SwiftKitSwift_Array_get") // FIXME: hardcoded for MySwiftClass
public func swiftjava_SwiftKitSwift_Array_get(
  rawPointer: UnsafeMutableRawPointer, // Array<T>
  index: Int,
  elementType: UnsafeMutableRawPointer // Metadata of T
) -> UnsafeMutableRawPointer {
  print("[swift][\(#fileID):\(#line)](\(#function) passed in rawPointer = \(rawPointer)")
  print("[swift][\(#fileID):\(#line)](\(#function) passed in index = \(index)")
  print("[swift][\(#fileID):\(#line)](\(#function) passed in metadata = \(elementType)")

  let array: UnsafeMutableBufferPointer<MySwiftClass> = UnsafeMutableBufferPointer(
    start: rawPointer.assumingMemoryBound(to: MySwiftClass.self),
    count: 999 // FIXME: we need this to be passed in
  )

  print("[swift][\(#fileID):\(#line)](\(#function) ARRAY[\(index)] = \(unsafeBitCast(array[index], to: UInt64.self))")
  let object = array[index]

  let objectPointer = unsafeBitCast(object, to: UnsafeMutableRawPointer.self)
  return _swiftjava_swift_retain(object: objectPointer)
}
