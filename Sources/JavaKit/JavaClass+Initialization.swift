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

import JavaRuntime

extension JavaClass {
  public typealias ObjectType = T

  /// Lookup this Java class within the given environment.
  @_nonoverride
  public convenience init(environment: JNIEnvironment? = nil) throws {
    let environment = try environment ?? JavaVirtualMachine.shared().environment()
    self.init(
      javaThis: try ObjectType.getJNIClass(in: environment),
      environment: environment
    )
  }
}
