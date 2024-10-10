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

// FIXME: this is a workaround until we can pass String to Swift directly
public func getTypeByStringByteArray(_ name: UnsafePointer<UInt8>) -> Any.Type? {
  let string = String(cString: name)
  let type = _typeByName(string)
  precondition(type != nil, "Unable to find type for name: \(string)!")
  return type
}

//// FIXME: this is internal in stdlib, it would make things easier here
//@_silgen_name("swift_stdlib_getTypeByMangledNameUntrusted")
//public func _getTypeByMangledNameUntrusted(
//  _ name: UnsafePointer<UInt8>,
//  _ nameLength: UInt)
//  -> Any.Type?
