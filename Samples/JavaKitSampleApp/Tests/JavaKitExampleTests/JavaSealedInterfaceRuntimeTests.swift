//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaKitExample
import SwiftJava
import Testing

/// Runtime tests for wrap-java's enum-based translation of Java
/// `sealed interface`. These exercise the code paths that only run
/// when a real JVM is present: JNI method lookup on the underlying
/// concrete class, and the enum's `init(javaHolder:)` dispatch that
/// wraps a returned parent-typed object back into the correct case.
@Suite
struct JavaSealedInterfaceRuntimeTests {

  let jvm = try JavaKitSampleJVM.shared

  /// Constructing an `Add` and wrapping it into the sealed enum via
  /// `init(javaHolder:)` picks the `.add` case (not `.unknown`).
  @Test
  func initJavaHolderDispatchesToAddCase() throws {
    let env = try jvm.environment()

    let add = Add(3, environment: env)
    let op = Op(javaHolder: add.javaHolder)

    switch op {
    case .add: break // expected
    case .mul(let v): Issue.record("expected .add, got .mul(\(v.eval()))")
    case .unknown(let v):
      Issue.record("expected .add, got .unknown(\(v.javaClass.getName()))")
    }

    // The enum's own `eval()` method (declared on the sealed interface)
    // must virtual-dispatch to Add.eval via JNI.
    #expect(op.eval() == 3)
  }

  /// Same as above but for `Mul`; guards against a broken always-first-case
  /// dispatch in the enum's `init(javaHolder:)`.
  @Test
  func initJavaHolderDispatchesToMulCase() throws {
    let env = try jvm.environment()

    let mul = Mul(7, environment: env)
    let op = Op(javaHolder: mul.javaHolder)

    switch op {
    case .mul: break // expected
    case .add(let v): Issue.record("expected .mul, got .add(\(v.eval()))")
    case .unknown(let v):
      Issue.record("expected .mul, got .unknown(\(v.javaClass.getName()))")
    }

    #expect(op.eval() == 7)
  }

  /// The static Java factories return the sealed interface type `Op`;
  /// wrap-java exposes them on `JavaClass<Op>`. The returned Swift value
  /// is an `Op!` enum whose case reflects the actual runtime class.
  @Test
  func staticFactoryReturnsCorrectEnumCase() throws {
    let env = try jvm.environment()

    let opClass = try JavaClass<Op>(environment: env)

    guard let add = opClass.makeAdd(10) else {
      Issue.record("makeAdd returned nil")
      return
    }
    switch add {
    case .add: break
    default: Issue.record("expected .add from makeAdd, got \(add)")
    }
    #expect(add.eval() == 10)

    guard let mul = opClass.makeMul(5) else {
      Issue.record("makeMul returned nil")
      return
    }
    switch mul {
    case .mul: break
    default: Issue.record("expected .mul from makeMul, got \(mul)")
    }
    #expect(mul.eval() == 5)
  }

  /// `combine(Op) -> Op` is declared on the sealed interface, so wrap-java
  /// emits it directly on the enum. Verifies that:
  /// 1. calling the method on the enum reaches the concrete Java subclass
  ///    (Add.combine adds, Mul.combine multiplies),
  /// 2. the returned enum value's case matches the concrete Java subclass
  ///    that Java produced (Add returns an Add, Mul returns a Mul).
  @Test
  func combineOnEnumDispatchesToConcreteSubclass() throws {
    let env = try jvm.environment()

    let opClass = try JavaClass<Op>(environment: env)
    let three = opClass.makeAdd(3)!
    let two = opClass.makeMul(2)!

    // 3 + 2 = 5, and the result should be an Add (Add.combine returns Add)
    let sum = three.combine(two)!
    #expect(sum.eval() == 5)
    switch sum {
    case .add: break
    default: Issue.record("expected .add from Add.combine, got \(sum)")
    }

    // 2 * 3 = 6, and the result should be a Mul (Mul.combine returns Mul)
    let product = two.combine(three)!
    #expect(product.eval() == 6)
    switch product {
    case .mul: break
    default: Issue.record("expected .mul from Mul.combine, got \(product)")
    }
  }

  /// The macro-generated `@JavaMethod` body on the enum uses
  /// `self.javaThis` from `self.javaHolder`, then `GetObjectClass` to
  /// resolve the method — so `eval()` on `.add(v)` must return the
  /// same value as `v.eval()` called on the concrete wrapper directly.
  @Test
  func methodOnEnumMatchesMethodOnConcreteSubclass() throws {
    let env = try jvm.environment()

    let add = Add(42, environment: env)
    let asOp: Op = .add(add)

    #expect(asOp.eval() == add.eval())
    #expect(asOp.eval() == 42)
  }
}
