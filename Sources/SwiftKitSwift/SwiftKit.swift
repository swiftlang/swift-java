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

@_silgen_name("getTypeByStringByteArray")
public func getTypeByStringByteArray(_ name: UnsafePointer<UInt8>) -> Any.Type? {
  let string = String(cString: name)
  let type = _typeByName(string)
  precondition(type != nil, "Unable to find type for name: \(string)!")
  return type
}

@_silgen_name("swift_retain")
public func _swiftjava_swift_retain(object: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer

@_silgen_name("swift_release")
public func _swiftjava_swift_release(object: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer

@_silgen_name("swift_retainCount")
public func _swiftjava_swift_retainCount(object: UnsafeMutableRawPointer) -> Int

@_silgen_name("swift_isUniquelyReferenced")
public func _swiftjava_swift_isUniquelyReferenced(object: UnsafeMutableRawPointer) -> Bool


 @_alwaysEmitIntoClient @_transparent
 internal func _swiftjava_withHeapObject<R>(
   of object: AnyObject,
   _ body: (UnsafeMutableRawPointer) -> R
 ) -> R {
   defer { _fixLifetime(object) }
   let unmanaged = Unmanaged.passUnretained(object)
   return body(unmanaged.toOpaque())
 }
