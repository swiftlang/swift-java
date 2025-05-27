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

/// Stores a reference to a Java object, managing it as a global reference so
/// that the Java virtual machine will not move or deallocate the object
/// while this instance is live.
public final class JavaObjectHolder {
  // FIXME: thread safety!
  public private(set) var object: jobject?
  public let environment: JNIEnvironment

  /// Take a reference to a Java object and promote it to a global reference
  /// so that the Java virtual machine will not garbage-collect it.
  public init(object: jobject, environment: JNIEnvironment) {
    self.object = environment.interface.NewGlobalRef(environment, object)
    self.environment = environment
  }

  /// Forget this Java object, meaning that it is no longer used from anywhere
  /// in Swift and the Java virtual machine is free to move or deallocate it.
  func forget() {
    if let object {
      environment.interface.DeleteGlobalRef(environment, object)
      self.object = nil
    }
  }

  deinit {
    // self.forget()
  }
}
