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

protocol SwiftJavaPluginProtocol {
  var verbose: Bool { get }
  var pluginName: String { get }

  func log(_ message: @autoclosure () -> String, terminator: String)
}

extension SwiftJavaPluginProtocol {
  func log(_ message: @autoclosure () -> String, terminator: String = "\n") {
    print("[\(pluginName)] \(message())", terminator: terminator)
  }

  func warn(_ message: @autoclosure () -> String, terminator: String = "\n") {
    print("[\(pluginName)][warning] \(message())", terminator: terminator)
  }
}
