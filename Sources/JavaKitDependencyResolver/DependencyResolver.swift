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

import SwiftJava

@JavaInterface("org.swift.jni.dependencies.DependencyResolver")
public struct DependencyResolver {
}

extension JavaClass<DependencyResolver> {

  @JavaStaticMethod
  public func resolveDependenciesToClasspath(
    projectBaseDirectory: String,
    dependencies: [String]) throws -> String

  @JavaStaticMethod
  public func hasDependencyResolverDependenciesLoaded() -> Bool

}
