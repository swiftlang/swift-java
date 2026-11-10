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

import SwiftJavaJNICore

/// `java.util.concurrent.ExecutionException`.
///
/// `Future.get()` throws this with the future's original failure as its cause.
@JavaClass("java.util.concurrent.ExecutionException")
open class ExecutionException: Exception {
  /// Java constructor `ExecutionException(Throwable cause)`.
  @JavaMethod
  @_nonoverride public convenience init(_ arg0: Throwable?, environment: JNIEnvironment? = nil)
}
