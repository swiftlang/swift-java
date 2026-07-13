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

/** Permitted subclass of {@link Op}; carries an add-flavored value. */
public final class Add implements Op {
  private final int value;
  public Add(int value) { this.value = value; }
  @Override public int eval() { return value; }
  @Override public Op combine(Op other) { return new Add(value + other.eval()); }
}
