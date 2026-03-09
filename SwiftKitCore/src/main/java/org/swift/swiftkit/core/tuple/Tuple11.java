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

public final class Tuple11<T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10> {
    private final T0 $0;
    private final T1 $1;
    private final T2 $2;
    private final T3 $3;
    private final T4 $4;
    private final T5 $5;
    private final T6 $6;
    private final T7 $7;
    private final T8 $8;
    private final T9 $9;
    private final T10 $10;

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

    public T0 $0() {
        return $0;
    }

    public T1 $1() {
        return $1;
    }

    public T2 $2() {
        return $2;
    }

    public T3 $3() {
        return $3;
    }

    public T4 $4() {
        return $4;
    }

    public T5 $5() {
        return $5;
    }

    public T6 $6() {
        return $6;
    }

    public T7 $7() {
        return $7;
    }

    public T8 $8() {
        return $8;
    }

    public T9 $9() {
        return $9;
    }

    public T10 $10() {
        return $10;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (\!(o instanceof Tuple11)) return false;
        Tuple11<?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?> other = (Tuple11<?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?>) o;
        return java.util.Objects.equals($0, other.$0) &&
                java.util.Objects.equals($1, other.$1) &&
                java.util.Objects.equals($2, other.$2) &&
                java.util.Objects.equals($3, other.$3) &&
                java.util.Objects.equals($4, other.$4) &&
                java.util.Objects.equals($5, other.$5) &&
                java.util.Objects.equals($6, other.$6) &&
                java.util.Objects.equals($7, other.$7) &&
                java.util.Objects.equals($8, other.$8) &&
                java.util.Objects.equals($9, other.$9) &&
                java.util.Objects.equals($10, other.$10);
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
