//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaLangReflect
import SwiftJava

/// Build a JVM method descriptor from a method name, parameter types, and return type.
/// E.g. `"getDisplayId()I"` or `"<init>(Landroid/content/Context;)V"`.
func jvmMethodDescriptor(
  name: String,
  parameterTypes: [JavaClass<JavaObject>?],
  returnType: JavaClass<JavaObject>?
) -> String {
  let params = parameterTypes.map { $0?.descriptorString() ?? "Ljava/lang/Object;" }.joined()
  let ret = returnType?.descriptorString() ?? "V" // void
  return "\(name)(\(params))\(ret)"
}

/// Build a JVM method descriptor for a reflected method.
func jvmMethodDescriptor(_ method: Method) -> String {
  jvmMethodDescriptor(
    name: method.getName(),
    parameterTypes: method.getParameterTypes(),
    returnType: method.getReturnType()
  )
}

/// Build a JVM method descriptor for a reflected constructor.
func jvmMethodDescriptor(_ constructor: some Executable) -> String {
  jvmMethodDescriptor(
    name: "<init>",
    parameterTypes: constructor.getParameterTypes(),
    returnType: nil
  )
}
