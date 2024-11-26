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

extension Optional where Wrapped: AnyJavaObject {
  func toJavaOptional() -> JavaOptional<Wrapped> {
    return try! JavaClass<JavaOptional<Wrapped>>().ofNullable(self?.as(JavaObject.self)).as(JavaOptional<Wrapped>.self)!
  }

  init?(_ javaOptional: JavaOptional<Wrapped>) {
    self = javaOptional.isPresent() ? javaOptional.get().as(Wrapped.self) : Optional<Wrapped>.none
  }
}
