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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif


// ==== --------------------------------------------------
// Thunks for Data

@_cdecl("swiftjava_getType_SwiftRuntimeFunctions_Data")
public func swiftjava_getType_SwiftRuntimeFunctions_Data() -> UnsafeMutableRawPointer /* Any.Type */ {
  unsafeBitCast(Data.self, to: UnsafeMutableRawPointer.self)
}

@_cdecl("swiftjava_SwiftRuntimeFunctions_Data_init_bytes_count")
public func swiftjava_SwiftRuntimeFunctions_Data_init_bytes_count(_ bytes: UnsafeRawPointer, _ count: Int, _ _result: UnsafeMutableRawPointer) {
  _result.assumingMemoryBound(to: Data.self).initialize(to: Data(bytes: bytes, count: count))
}

@_cdecl("swiftjava_SwiftRuntimeFunctions_Data_init__")
public func swiftjava_SwiftRuntimeFunctions_Data_init__(_ bytes_pointer: UnsafeRawPointer, _ bytes_count: Int, _ _result: UnsafeMutableRawPointer) {
  _result.assumingMemoryBound(to: Data.self).initialize(to: Data([UInt8](UnsafeRawBufferPointer(start: bytes_pointer, count: bytes_count))))
}

@_cdecl("swiftjava_SwiftRuntimeFunctions_Data_count$get")
public func swiftjava_SwiftRuntimeFunctions_Data_count$get(_ self: UnsafeRawPointer) -> Int {
  self.assumingMemoryBound(to: Data.self).pointee.count
}

@_cdecl("swiftjava_SwiftRuntimeFunctions_Data_withUnsafeBytes__")
public func swiftjava_SwiftRuntimeFunctions_Data_withUnsafeBytes__(_ body: @convention(c) (UnsafeRawPointer?, Int) -> Void, _ self: UnsafeRawPointer) {
  self.assumingMemoryBound(to: Data.self).pointee.withUnsafeBytes({ (_0) in
    body(_0.baseAddress, _0.count)
  })
}

@_cdecl("swiftjava_SwiftRuntimeFunctions_Data_copyBytes__")
public func swiftjava_SwiftRuntimeFunctions_Data_copyBytes__(
  selfPointer: UnsafeRawPointer,
  destinationPointer: UnsafeMutableRawPointer,
  count: Int
) {
  let data = selfPointer.assumingMemoryBound(to: Data.self).pointee
  data.withUnsafeBytes { buffer in
    destinationPointer.copyMemory(from: buffer.baseAddress!, byteCount: count)
  }
}

// ==== --------------------------------------------------
// Thunks for DataProtocol

@_cdecl("swiftjava_getType_SwiftRuntimeFunctions_DataProtocol")
public func swiftjava_getType_SwiftRuntimeFunctions_DataProtocol() -> UnsafeMutableRawPointer /* Any.Type */ {
  unsafeBitCast((any DataProtocol).self, to: UnsafeMutableRawPointer.self)
}
