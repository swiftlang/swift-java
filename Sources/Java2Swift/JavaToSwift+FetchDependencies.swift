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

import ArgumentParser
import Java2SwiftLib
import JavaKit
import JavaKitJar
import JavaKitReflection
import SwiftSyntax
import Java2SwiftLib
import JavaKitDependencyResolver

extension JavaToSwift {
  func fetchDependencies(
    config: Configuration,
    environment: JNIEnvironment) throws -> JavaClasspath {
    print("FETCH DEPENDENCIES FOR: \(config.dependencies)")
    let resolverClass = try JavaClass<DependencyResolver>(environment: environment)
    let deps = config.dependencies.map { "\($0)" }
    let classpath = try resolverClass.getClasspathWithDependency(dependencies: deps)
    print("RESOLVED CLASSPATH: \(classpath)")

    return .init(classpath)
  }
}

struct JavaClasspath: CustomStringConvertible {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  var description: String {
    "JavaClasspath(value: \(value))"
  }
}