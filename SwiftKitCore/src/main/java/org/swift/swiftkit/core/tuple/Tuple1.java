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

package org.swift.swiftkit.core.tuple;

/**
 * Corresponds to Swift's built-in 1-element tuple type <code>(T0)</code>.
 * Elements are accessed via public final fields <code>$0</code>, <code>$1</code>, etc.
 */
public final class Tuple1<T0> {
    public final T0 $0;

    public Tuple1(T0 $0) {
        this.$0 = $0;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple1)) return false;
        Tuple1 o = (Tuple1) other;
        return java.util.Objects.equals(this.$0, o.$0);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0);
    }

    @Override
    public String toString() {
        return "Tuple1(" + $0 + ")";
    }
}
