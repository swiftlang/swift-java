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

public final class Tuple1<T0> {
    private final T0 $0;

    public Tuple1(T0 $0) {
        this.$0 = $0;
    }

    public T0 $0() {
        return $0;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (\!(o instanceof Tuple1)) return false;
        Tuple1<?> other = (Tuple1<?>) o;
        return java.util.Objects.equals($0, other.$0);
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
