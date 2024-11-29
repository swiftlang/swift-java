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
import Foundation
import JavaKitJar
import Java2SwiftLib
import JavaKitDependencyResolver
import JavaKitConfigurationShared

extension JavaToSwift {
  func fetchDependencies(projectName: String,
                         dependencies: [JavaDependencyDescriptor],
                         baseClasspath: [String]) throws -> JavaClasspath {
    let deps = dependencies.map { $0.descriptionGradleStyle }
    print("[debug][swift-java] Fetch dependencies: \(deps)")

    let jvm = try JavaVirtualMachine.shared(classPath: baseClasspath)
    // let jvm = try ensureDependencyResolverDependenciesLoaded(baseClasspath: baseClasspath)

    let resolverClass = try JavaClass<DependencyResolver>(environment: jvm.environment())
    let classpath = try resolverClass.resolveDependenciesToClasspath(
      projectBaseDirectory: URL(fileURLWithPath: ".").path,
      dependencies: deps)

    let entryCount = classpath.split(separator: ":").count
    print("[debug][swift-java] Resolved classpath for \(deps.count) dependencies: classpath entries: \(entryCount)... ", terminator: "")
    print("done.".green)
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
