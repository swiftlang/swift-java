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
 * Corresponds to Swift's built-in 2-element tuple type <code>(T0, T1)</code>.
 * Elements are accessed via public final fields <code>$0</code>, <code>$1</code>, etc.
 */
public class Tuple2<T0, T1> {
    public final T0 $0;
    public final T1 $1;

    public Tuple2(T0 $0, T1 $1) {
        this.$0 = $0;
        this.$1 = $1;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple2)) return false;
        Tuple2 o = (Tuple2) other;
        return java.util.Objects.equals(this.$0, o.$0) &&
                java.util.Objects.equals(this.$1, o.$1);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1);
    }

    @Override
    public String toString() {
        return "Tuple2(" + $0 + ", " + $1 + ")";
    }
}
