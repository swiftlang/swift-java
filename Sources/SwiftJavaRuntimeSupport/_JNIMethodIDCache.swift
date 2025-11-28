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

import CSwiftJavaJNI
import SwiftJava

/// A cache used to hold references for JNI method and classes.
///
/// This type is used internally in by the outputted JExtract wrappers
/// to improve performance of any JNI lookups.
public final class _JNIMethodIDCache: Sendable {
  public struct Method: Hashable {
    public let name: String
    public let signature: String
    public let isStatic: Bool

    public init(name: String, signature: String, isStatic: Bool = false) {
      self.name = name
      self.signature = signature
      self.isStatic = isStatic
    }
  }

  nonisolated(unsafe) let _class: jclass?
  nonisolated(unsafe) let methods: [Method: jmethodID]

  public var javaClass: jclass {
    self._class!
  }

  /// An optional reference to a java object holder
  /// if we cached this class through the class loader
  /// This is to make sure that the underlying reference remains valid
  nonisolated(unsafe) private let javaObjectHolder: JavaObjectHolder?

  public init(className: String, methods: [Method], isSystemClass: Bool) {
    let environment = try! JavaVirtualMachine.shared().environment()

    let clazz: jobject
    if isSystemClass {
      guard let jniClass = environment.interface.FindClass(environment, className) else {
            fatalError("Class \(className) could not be found!")
          }
      clazz = environment.interface.NewGlobalRef(environment, jniClass)!
      self.javaObjectHolder = nil
    } else {
      guard let javaClass = try? JNI.shared.applicationClassLoader.loadClass(className.replacingOccurrences(of: "/", with: ".")) else {
        fatalError("Non-system class \(className) could not be found!")
      }
      clazz = javaClass.javaThis
      self.javaObjectHolder = javaClass.javaHolder
    }
    self._class = clazz
    self.methods = methods.reduce(into: [:]) { (result, method) in
      if method.isStatic {
        if let methodID = environment.interface.GetStaticMethodID(environment, clazz, method.name, method.signature) {
          result[method] = methodID
        } else {
          fatalError("Static method \(method.signature) with signature \(method.signature) not found in class \(className)")
        }
      } else {
        if let methodID = environment.interface.GetMethodID(environment, clazz, method.name, method.signature) {
          result[method] = methodID
        } else {
          fatalError("Method \(method.signature) with signature \(method.signature) not found in class \(className)")
        }
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
