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
 * Corresponds to Swift's built-in 21-element tuple type <code>(T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)</code>.
 * Elements are accessed via public final fields <code>$0</code>, <code>$1</code>, etc.
 */
public class Tuple21<T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20> {
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

    public Tuple21(T0 $0, T1 $1, T2 $2, T3 $3, T4 $4, T5 $5, T6 $6, T7 $7, T8 $8, T9 $9, T10 $10, T11 $11, T12 $12, T13 $13, T14 $14, T15 $15, T16 $16, T17 $17, T18 $18, T19 $19, T20 $20) {
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
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple21)) return false;
        Tuple21 o = (Tuple21) other;
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
                java.util.Objects.equals(this.$20, o.$20);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20);
    }

    @Override
    public String toString() {
        return "Tuple21(" + $0 + ", " + $1 + ", " + $2 + ", " + $3 + ", " + $4 + ", " + $5 + ", " + $6 + ", " + $7 + ", " + $8 + ", " + $9 + ", " + $10 + ", " + $11 + ", " + $12 + ", " + $13 + ", " + $14 + ", " + $15 + ", " + $16 + ", " + $17 + ", " + $18 + ", " + $19 + ", " + $20 + ")";
    }
}
