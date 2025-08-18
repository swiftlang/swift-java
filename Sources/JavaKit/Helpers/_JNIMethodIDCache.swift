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

/// A cache used to hold references for JNI method and classes.
///
/// This type is used internally in by the outputted JExtract wrappers
/// to improve performance of any JNI lookups.
public final class _JNIMethodIDCache: Sendable {
  public struct Method: Hashable {
    public let name: String
    public let signature: String

    public init(name: String, signature: String) {
      self.name = name
      self.signature = signature
    }
  }

  nonisolated(unsafe) let _class: jclass?
  nonisolated(unsafe) let methods: [Method: jmethodID]

  public var javaClass: jclass {
    self._class!
  }

  public init(environment: UnsafeMutablePointer<JNIEnv?>!, className: String, methods: [Method]) {
    guard let clazz = environment.interface.FindClass(environment, className) else {
      fatalError("Class \(className) could not be found!")
    }
    self._class = environment.interface.NewGlobalRef(environment, clazz)!
    self.methods = methods.reduce(into: [:]) { (result, method) in
      if let methodID = environment.interface.GetMethodID(environment, clazz, method.name, method.signature) {
        result[method] = methodID
      } else {
        fatalError("Method \(method.signature) with signature \(method.signature) not found in class \(className)")
      }
    }
  }


  public subscript(_ method: Method) -> jmethodID? {
    methods[method]
  }

  public func cleanup(environment: UnsafeMutablePointer<JNIEnv?>!) {
    environment.interface.DeleteGlobalRef(environment, self._class)
  }
}
