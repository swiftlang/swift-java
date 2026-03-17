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
 * Corresponds to Swift's built-in 10-element tuple type <code>(T0, T1, T2, T3, T4, T5, T6, T7, T8, T9)</code>.
 * Elements are accessed via public final fields <code>$0</code>, <code>$1</code>, etc.
 */
public final class Tuple10<T0, T1, T2, T3, T4, T5, T6, T7, T8, T9> {
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

    public Tuple10(T0 $0, T1 $1, T2 $2, T3 $3, T4 $4, T5 $5, T6 $6, T7 $7, T8 $8, T9 $9) {
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
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple10)) return false;
        Tuple10 o = (Tuple10) other;
        return java.util.Objects.equals(this.$0, o.$0) &&
                java.util.Objects.equals(this.$1, o.$1) &&
                java.util.Objects.equals(this.$2, o.$2) &&
                java.util.Objects.equals(this.$3, o.$3) &&
                java.util.Objects.equals(this.$4, o.$4) &&
                java.util.Objects.equals(this.$5, o.$5) &&
                java.util.Objects.equals(this.$6, o.$6) &&
                java.util.Objects.equals(this.$7, o.$7) &&
                java.util.Objects.equals(this.$8, o.$8) &&
                java.util.Objects.equals(this.$9, o.$9);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1, $2, $3, $4, $5, $6, $7, $8, $9);
    }

    @Override
    public String toString() {
        return "Tuple10(" + $0 + ", " + $1 + ", " + $2 + ", " + $3 + ", " + $4 + ", " + $5 + ", " + $6 + ", " + $7 + ", " + $8 + ", " + $9 + ")";
    }
}
