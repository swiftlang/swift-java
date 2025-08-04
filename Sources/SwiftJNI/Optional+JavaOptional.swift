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

public extension Optional where Wrapped: AnyJavaObject {
  func toJavaOptional() -> JavaOptional<Wrapped> {
    return try! JavaClass<JavaOptional<Wrapped>>().ofNullable(self?.as(JavaObject.self)).as(JavaOptional<Wrapped>.self)!
  }

  init(javaOptional: JavaOptional<Wrapped>?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.get().as(Wrapped.self) : Optional<Wrapped>.none
    } else {
      self = nil
    }
  }
}

public extension Optional where Wrapped == Double {
  func toJavaOptional() -> JavaOptionalDouble {
    if let self {
      return try! JavaClass<JavaOptionalDouble>().of(self)!
    } else {
      return try! JavaClass<JavaOptionalDouble>().empty()!
    }
  }

  init(javaOptional: JavaOptionalDouble?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.getAsDouble() : nil
    } else {
      self = nil
    }
  }
}

public extension Optional where Wrapped == Int32 {
  func toJavaOptional() -> JavaOptionalInt {
    if let self {
      return try! JavaClass<JavaOptionalInt>().of(self)!
    } else {
      return try! JavaClass<JavaOptionalInt>().empty()!
    }
  }

  init(javaOptional: JavaOptionalInt?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.getAsInt() : nil
    } else {
      self = nil
    }
  }
}

public extension Optional where Wrapped == Int64 {
  func toJavaOptional() -> JavaOptionalLong {
    if let self {
      return try! JavaClass<JavaOptionalLong>().of(self)!
    } else {
      return try! JavaClass<JavaOptionalLong>().empty()!
    }
  }

  init(javaOptional: JavaOptionalLong?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.getAsLong() : nil
    } else {
      self = nil
    }
  }
}
