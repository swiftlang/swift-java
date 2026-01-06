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

import JavaKitExample

import SwiftJava
import JavaUtilFunction

/// Utility to configure the classpath and native libraries paths for writing tests against 
/// classes defined in this JavaKitExample project
struct JavaKitSampleJVM {

  static var shared: JavaVirtualMachine = {
    try! JavaVirtualMachine.shared(
      classpath: [
        ".build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java",
      ],
      vmOptions: [
        KnownJavaVMOptions.javaLibraryPath(".build/\(SwiftPlatform.debugOrRelease)/"),
      ]
    )
  }()

}