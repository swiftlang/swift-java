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

package com.example.swift;

/**
 * Java sealed interface used to smoke-test wrap-java's enum-based
 * translation of {@code sealed interface}. Verifies that:
 * <ol>
 *   <li>the parent interface is wrapped as a Swift {@code enum} with
 *       a case per permitted subclass,</li>
 *   <li>methods declared on the parent interface remain callable on
 *       the enum itself (JNI virtual-dispatches to the underlying
 *       concrete Java class),</li>
 *   <li>returning the parent interface type from Java produces a
 *       Swift enum value whose case matches the actual runtime class.</li>
 * </ol>
 */
public sealed interface Op permits Add, Mul {
  int eval();
  Op combine(Op other);

  static Op makeAdd(int x) { return new Add(x); }
  static Op makeMul(int x) { return new Mul(x); }
}
