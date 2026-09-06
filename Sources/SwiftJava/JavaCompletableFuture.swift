//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJavaJNICore

@JavaClass("java.util.concurrent.CompletableFuture")
open class JavaCompletableFuture: JavaObject {
  @JavaMethod
  public func get() throws -> JavaObject?
}

@JavaClass("org.swift.swiftkit.core.SimpleCompletableFuture")
open class JavaSimpleCompletableFuture: JavaObject {
  @JavaMethod
  public func get() throws -> JavaObject?
}
