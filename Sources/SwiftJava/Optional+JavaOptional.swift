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
  public func toJavaOptional() -> JavaOptional<Wrapped> {
    try! JavaClass<JavaOptional<Wrapped>>().ofNullable(self?.as(JavaObject.self)).as(JavaOptional<Wrapped>.self)!
  }

  public init(javaOptional: JavaOptional<Wrapped>?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.get().as(Wrapped.self) : Optional<Wrapped>.none
    } else {
      self = nil
    }
  }
}

extension Optional where Wrapped == Double {
  public func toJavaOptional() -> JavaOptionalDouble {
    if let self {
      return try! JavaClass<JavaOptionalDouble>().of(self)!
    } else {
      return try! JavaClass<JavaOptionalDouble>().empty()!
    }
  }

  public init(javaOptional: JavaOptionalDouble?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.getAsDouble() : nil
    } else {
      self = nil
    }
  }
}

extension Optional where Wrapped == Int32 {
  public func toJavaOptional() -> JavaOptionalInt {
    if let self {
      return try! JavaClass<JavaOptionalInt>().of(self)!
    } else {
      return try! JavaClass<JavaOptionalInt>().empty()!
    }
  }

  public init(javaOptional: JavaOptionalInt?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.getAsInt() : nil
    } else {
      self = nil
    }
  }
}

extension Optional where Wrapped == Int64 {
  public func toJavaOptional() -> JavaOptionalLong {
    if let self {
      return try! JavaClass<JavaOptionalLong>().of(self)!
    } else {
      return try! JavaClass<JavaOptionalLong>().empty()!
    }
  }

  public init(javaOptional: JavaOptionalLong?) {
    if let javaOptional {
      self = javaOptional.isPresent() ? javaOptional.getAsLong() : nil
    } else {
      self = nil
    }
  }
}

extension JavaOptional {
  public func empty(environment: JNIEnvironment? = nil) -> JavaOptional<T>! {
    guard let env = try? environment ?? JavaVirtualMachine.shared().environment() else {
      return nil
    }

    guard let opt = try? JavaClass<JavaOptional<T>>(environment: env).empty() else {
      return nil
    }

    return opt.as(JavaOptional<T>.self)
  }
}
