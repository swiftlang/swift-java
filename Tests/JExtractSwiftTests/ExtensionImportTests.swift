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

import JExtractSwiftLib
import Testing

final class ExtensionImportTests {
  let interfaceFile =
    """
    extension MyStruct {
      public func methodInExtension() {}
    }

    public struct MyStruct {}
    """

  @Test("Import extensions: Swift thunks")
  func data_swiftThunk() throws {
    try assertOutput(
      input: interfaceFile,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_getType_SwiftModule_MyStruct")
        public func swiftjava_getType_SwiftModule_MyStruct() -> UnsafeMutableRawPointer /* Any.Type */ {
          return unsafeBitCast(MyStruct.self, to: UnsafeMutableRawPointer.self)
        }
        """,
        """
        @_cdecl("swiftjava_SwiftModule_MyStruct_methodInExtension")
        public func swiftjava_SwiftModule_MyStruct_methodInExtension(_ self: UnsafeRawPointer) {
          self.assumingMemoryBound(to: MyStruct.self).pointee.methodInExtension()
        }
        """,
      ]
    )
  }
}
