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

public final class Tuple2<T0, T1> {
    private final T0 $0;
    private final T1 $1;

    public Tuple2(T0 $0, T1 $1) {
        this.$0 = $0;
        this.$1 = $1;
    }

    public T0 $0() {
        return $0;
    }

    public T1 $1() {
        return $1;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (\!(o instanceof Tuple2)) return false;
        Tuple2<?, ?> other = (Tuple2<?, ?>) o;
        return java.util.Objects.equals($0, other.$0) &&
                java.util.Objects.equals($1, other.$1);
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
