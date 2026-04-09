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
 * Corresponds to Swift's built-in 11-element tuple type <code>(T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)</code>.
 * Elements are accessed via public final fields <code>$0</code>, <code>$1</code>, etc.
 * @param <T0> the type of element 0
 * @param <T1> the type of element 1
 * @param <T2> the type of element 2
 * @param <T3> the type of element 3
 * @param <T4> the type of element 4
 * @param <T5> the type of element 5
 * @param <T6> the type of element 6
 * @param <T7> the type of element 7
 * @param <T8> the type of element 8
 * @param <T9> the type of element 9
 * @param <T10> the type of element 10
 */
public class Tuple11<T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10> {
    public final T0 $0;
    public final T1 $1;
    public final T2 $2;
    public final T3 $3;
    public final T4 $4;
    public final T5 $5;
    public final T6 $6;
    public final T7 $7;
    public final T8 $8;
    public final T9 $9;
    public final T10 $10;

    public Tuple11(T0 $0, T1 $1, T2 $2, T3 $3, T4 $4, T5 $5, T6 $6, T7 $7, T8 $8, T9 $9, T10 $10) {
        this.$0 = $0;
        this.$1 = $1;
        this.$2 = $2;
        this.$3 = $3;
        this.$4 = $4;
        this.$5 = $5;
        this.$6 = $6;
        this.$7 = $7;
        this.$8 = $8;
        this.$9 = $9;
        this.$10 = $10;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple11)) return false;
        Tuple11 o = (Tuple11) other;
        return java.util.Objects.equals(this.$0, o.$0) &&
                java.util.Objects.equals(this.$1, o.$1) &&
                java.util.Objects.equals(this.$2, o.$2) &&
                java.util.Objects.equals(this.$3, o.$3) &&
                java.util.Objects.equals(this.$4, o.$4) &&
                java.util.Objects.equals(this.$5, o.$5) &&
                java.util.Objects.equals(this.$6, o.$6) &&
                java.util.Objects.equals(this.$7, o.$7) &&
                java.util.Objects.equals(this.$8, o.$8) &&
                java.util.Objects.equals(this.$9, o.$9) &&
                java.util.Objects.equals(this.$10, o.$10);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
    }

    @Override
    public String toString() {
        return "Tuple11(" + $0 + ", " + $1 + ", " + $2 + ", " + $3 + ", " + $4 + ", " + $5 + ", " + $6 + ", " + $7 + ", " + $8 + ", " + $9 + ", " + $10 + ")";
    }
}
