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
 * Corresponds to Swift's built-in 23-element tuple type <code>(T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22)</code>.
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
 * @param <T11> the type of element 11
 * @param <T12> the type of element 12
 * @param <T13> the type of element 13
 * @param <T14> the type of element 14
 * @param <T15> the type of element 15
 * @param <T16> the type of element 16
 * @param <T17> the type of element 17
 * @param <T18> the type of element 18
 * @param <T19> the type of element 19
 * @param <T20> the type of element 20
 * @param <T21> the type of element 21
 * @param <T22> the type of element 22
 */
public class Tuple23<T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22> {
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
    public final T11 $11;
    public final T12 $12;
    public final T13 $13;
    public final T14 $14;
    public final T15 $15;
    public final T16 $16;
    public final T17 $17;
    public final T18 $18;
    public final T19 $19;
    public final T20 $20;
    public final T21 $21;
    public final T22 $22;

    public Tuple23(T0 $0, T1 $1, T2 $2, T3 $3, T4 $4, T5 $5, T6 $6, T7 $7, T8 $8, T9 $9, T10 $10, T11 $11, T12 $12, T13 $13, T14 $14, T15 $15, T16 $16, T17 $17, T18 $18, T19 $19, T20 $20, T21 $21, T22 $22) {
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
        this.$11 = $11;
        this.$12 = $12;
        this.$13 = $13;
        this.$14 = $14;
        this.$15 = $15;
        this.$16 = $16;
        this.$17 = $17;
        this.$18 = $18;
        this.$19 = $19;
        this.$20 = $20;
        this.$21 = $21;
        this.$22 = $22;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple23)) return false;
        Tuple23 o = (Tuple23) other;
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
                java.util.Objects.equals(this.$10, o.$10) &&
                java.util.Objects.equals(this.$11, o.$11) &&
                java.util.Objects.equals(this.$12, o.$12) &&
                java.util.Objects.equals(this.$13, o.$13) &&
                java.util.Objects.equals(this.$14, o.$14) &&
                java.util.Objects.equals(this.$15, o.$15) &&
                java.util.Objects.equals(this.$16, o.$16) &&
                java.util.Objects.equals(this.$17, o.$17) &&
                java.util.Objects.equals(this.$18, o.$18) &&
                java.util.Objects.equals(this.$19, o.$19) &&
                java.util.Objects.equals(this.$20, o.$20) &&
                java.util.Objects.equals(this.$21, o.$21) &&
                java.util.Objects.equals(this.$22, o.$22);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22);
    }

    @Override
    public String toString() {
        return "Tuple23(" + $0 + ", " + $1 + ", " + $2 + ", " + $3 + ", " + $4 + ", " + $5 + ", " + $6 + ", " + $7 + ", " + $8 + ", " + $9 + ", " + $10 + ", " + $11 + ", " + $12 + ", " + $13 + ", " + $14 + ", " + $15 + ", " + $16 + ", " + $17 + ", " + $18 + ", " + $19 + ", " + $20 + ", " + $21 + ", " + $22 + ")";
    }
}
