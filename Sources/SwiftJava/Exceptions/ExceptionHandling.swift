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

import struct JavaTypes.JavaException

extension JNIEnvironment {
  /// Execute a JNI call and check for an exception at the end. Translate
  /// any Java exception into an error.
  func translatingJNIExceptions<Result>(body: () throws -> Result) throws -> Result {
    let result = try body()

    // Check whether a Java exception occurred.
    if let exception = interface.ExceptionOccurred(self) {
      interface.ExceptionClear(self)
      throw Throwable(javaThis: exception, environment: self)
    }

    return result
  }

  /// Throw the given Swift error as a Java exception.
  public func throwAsException(_ error: some Error) {
    // If we're throwing something that's already a Java Throwable object,
    // post it directly.
    if let javaObject = error as? any AnyJavaObject,
      let throwable = javaObject.as(Throwable.self)
    {
      _ = interface.Throw(self, throwable.javaThis)
      return
    }

    // Otherwise, create a exception with a message.
    _ = try! Exception.withJNIClass(in: self) { exceptionClass in
      interface.ThrowNew(self, exceptionClass, String(describing: error))
    }
  }

  public func throwJavaException(javaException: JavaException) {
    guard let exceptionClass = self.interface.FindClass(self, javaException.type.className!) else {
      // Otherwise, create a exception with a message.
      _ = try! Exception.withJNIClass(in: self) { exceptionClass in
        interface.ThrowNew(self, exceptionClass, "An exception(\(String(describing: javaException))) occured!")
      }
      return
    }

    _ = interface.ThrowNew(self, exceptionClass, javaException.message ?? "")
  }
}
