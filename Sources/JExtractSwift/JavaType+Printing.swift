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

import Foundation
import SwiftBasicFormat
import SwiftParser
import SwiftSyntax
import JavaTypes

extension JavaType {
  /// Returns a 'handle' name to pass to the `invoke` call as well as the
  /// `FunctionDescription` and `MethodHandle` of the downcall handle for this parameter.
  ///
  /// Pass the prior to `invoke`, and directly render the latter in the Java wrapper downcall function body.
  func prepareClosureDowncallHandle(decl: ImportedFunc, parameter: String) -> String {
    let varNameBase = "\(decl.baseIdentifier)_\(parameter)"
    let handle = "\(varNameBase)_handle$"
    let desc = "\(varNameBase)_desc$"

    if self == .javaLangRunnable {
      return
        """
        FunctionDescriptor \(desc) = FunctionDescriptor.ofVoid();
        MethodHandle \(handle) = MethodHandles.lookup()
                 .findVirtual(Runnable.class, "run",
                         \(desc).toMethodType());
        \(handle) = \(handle).bindTo(\(parameter));

        Linker linker = Linker.nativeLinker();
        MemorySegment \(parameter)$ = linker.upcallStub(\(handle), \(desc), arena);
        """
    }

    fatalError("Cannot render closure downcall handle for: \(self), in: \(decl), parameter: \(parameter)")
  }
}
