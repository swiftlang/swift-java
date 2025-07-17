//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.swiftkit.core.primitives;

import org.swift.swiftkit.core.NotImplementedException;

import java.math.BigInteger;
import java.util.Objects;

/**
 * Represents an 32-bit unsigned integer, with a value between 0 and (@{@code 2^64 - 1}).
 *
 * <p> Equivalent to the {@code UInt32} Swift type.
 */
public final class UnsignedLong extends Number implements Comparable<UnsignedLong> {

    public final static UnsignedLong ZERO = representedByBitsOf(0);
    public final static UnsignedLong MAX_VALUE = representedByBitsOf(-1);

    public final static long BIT_COUNT = 64;

    final long value;

    private UnsignedLong(long bits) {
        this.value = bits;
    }

    /**
     * Accept a signed Java @{code int} value, and interpret it as-if it was an unsigned value.
     * In other words, do not interpret the negative bit as "negative", but as part of the unsigned integers value.
     *
     * @param bits bit value to store in this unsigned integer
     * @return unsigned integer representation of the passed in value
     */
    public static UnsignedLong representedByBitsOf(long bits) {
        return new UnsignedLong(bits);
    }

    public static UnsignedLong valueOf(long value) throws UnsignedOverflowException {
        return representedByBitsOf(value);
    }

    @Override
    public int compareTo(UnsignedLong o) {
        Objects.requireNonNull(o);
        return Long.compare(this.value + Long.MIN_VALUE, o.value + Long.MIN_VALUE);
    }

    @Override
    public int intValue() {
        return (int) value;
    }

    @Override
    public long longValue() {
        return value;
    }

    @Override
    public float floatValue() {
        throw new NotImplementedException("Not implemented");
    }

    @Override
    public double doubleValue() {
        throw new NotImplementedException("Not implemented");
    }

    public BigInteger bigIntegerValue() {
        return BigInteger.valueOf(value);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        UnsignedLong that = (UnsignedLong) o;
        return value == that.value;
    }

    @Override
    public int hashCode() {
        return Long.hashCode(value);
    }
}
