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

import SwiftJava

// TODO: We should be able to autogenerate this as an extension based on
// knowing that JavaClass was defined elsewhere.
extension JavaClass {
  @JavaMethod
  public func getDeclaredMethods() -> [Method?]

  @JavaMethod
  public func getMethods() -> [Method?]

  @JavaMethod
  public func getDeclaredMethod(
    _ name: String,
    _ parameterTypes: [JavaClass<JavaObject>?]
  ) throws -> Method?

  @JavaMethod
  public func getFields() -> [Field?]

  @JavaMethod
  public func getConstructors() -> [Constructor<ObjectType>?]

  @JavaMethod
  public func getParameters() -> [Parameter?]

  @JavaMethod
  public func getTypeParameters() -> [TypeVariable<JavaClass<JavaObject>>?]

  @JavaMethod
  public func getGenericInterfaces() -> [Type?]

  @JavaMethod
  public func getAnnotations() -> [Annotation?]
}
