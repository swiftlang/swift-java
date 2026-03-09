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

public final class Tuple5<T0, T1, T2, T3, T4> {
    private final T0 $0;
    private final T1 $1;
    private final T2 $2;
    private final T3 $3;
    private final T4 $4;

    public Tuple5(T0 $0, T1 $1, T2 $2, T3 $3, T4 $4) {
        this.$0 = $0;
        this.$1 = $1;
        this.$2 = $2;
        this.$3 = $3;
        this.$4 = $4;
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

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (\!(o instanceof Tuple5)) return false;
        Tuple5<?, ?, ?, ?, ?> other = (Tuple5<?, ?, ?, ?, ?>) o;
        return java.util.Objects.equals($0, other.$0) &&
                java.util.Objects.equals($1, other.$1) &&
                java.util.Objects.equals($2, other.$2) &&
                java.util.Objects.equals($3, other.$3) &&
                java.util.Objects.equals($4, other.$4);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1, $2, $3, $4);
    }

    @Override
    public String toString() {
        return "Tuple5(" + $0 + ", " + $1 + ", " + $2 + ", " + $3 + ", " + $4 + ")";
    }
}
