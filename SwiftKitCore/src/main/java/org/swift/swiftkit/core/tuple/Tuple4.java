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
 * Corresponds to Swift's built-in 4-element tuple type <code>(T0, T1, T2, T3)</code>.
 * Elements are accessed via public final fields <code>$0</code>, <code>$1</code>, etc.
 * @param <T0> the type of element 0
 * @param <T1> the type of element 1
 * @param <T2> the type of element 2
 * @param <T3> the type of element 3
 */
public class Tuple4<T0, T1, T2, T3> {
    public final T0 $0;
    public final T1 $1;
    public final T2 $2;
    public final T3 $3;

    public Tuple4(T0 $0, T1 $1, T2 $2, T3 $3) {
        this.$0 = $0;
        this.$1 = $1;
        this.$2 = $2;
        this.$3 = $3;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple4)) return false;
        Tuple4 o = (Tuple4) other;
        return java.util.Objects.equals(this.$0, o.$0) &&
                java.util.Objects.equals(this.$1, o.$1) &&
                java.util.Objects.equals(this.$2, o.$2) &&
                java.util.Objects.equals(this.$3, o.$3);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1, $2, $3);
    }

    @Override
    public String toString() {
        return "Tuple4(" + $0 + ", " + $1 + ", " + $2 + ", " + $3 + ")";
    }
}
