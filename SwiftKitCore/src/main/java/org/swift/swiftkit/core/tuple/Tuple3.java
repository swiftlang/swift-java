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
 * Corresponds to Swift's built-in 3-element tuple type <code>(T0, T1, T2)</code>.
 * Elements are accessed via public final fields <code>$0</code>, <code>$1</code>, etc.
 */
public class Tuple3<T0, T1, T2> {
    public final T0 $0;
    public final T1 $1;
    public final T2 $2;

    public Tuple3(T0 $0, T1 $1, T2 $2) {
        this.$0 = $0;
        this.$1 = $1;
        this.$2 = $2;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof Tuple3)) return false;
        Tuple3 o = (Tuple3) other;
        return java.util.Objects.equals(this.$0, o.$0) &&
                java.util.Objects.equals(this.$1, o.$1) &&
                java.util.Objects.equals(this.$2, o.$2);
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash($0, $1, $2);
    }

    @Override
    public String toString() {
        return "Tuple3(" + $0 + ", " + $1 + ", " + $2 + ")";
    }
}
