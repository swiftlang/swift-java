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

import java.math.BigInteger;
import java.util.Objects;

/**
 * Represents an 32-bit unsigned integer, with a value between 0 and (@{@code 2^32 - 1}).
 *
 * <p> Equivalent to the {@code UInt32} Swift type.
 */
public final class UnsignedInteger extends Number implements Comparable<UnsignedInteger> {

    public final static UnsignedInteger ZERO = representedByBitsOf(0);
    public final static UnsignedInteger MAX_VALUE = representedByBitsOf(-1);
    public final static long MASK = 0xffffffffL;

    public final static long BIT_COUNT = 32;

    final int value;

    private UnsignedInteger(int bits) {
        this.value = bits;
    }

    /**
     * Accept a signed Java @{code int} value, and interpret it as-if it was an unsigned value.
     * In other words, do not interpret the negative bit as "negative", but as part of the unsigned integers value.
     *
     * @param bits bit value to store in this unsigned integer
     * @return unsigned integer representation of the passed in value
     */
    public static UnsignedInteger representedByBitsOf(int bits) {
        return new UnsignedInteger(bits);
    }

    public static UnsignedInteger valueOf(long value) throws UnsignedOverflowException {
        if ((value & UnsignedInteger.MASK) != value) {
            throw new UnsignedOverflowException(String.valueOf(value), UnsignedInteger.class);
        }
        return representedByBitsOf((int) value);
    }

    @Override
    public int compareTo(UnsignedInteger o) {
        Objects.requireNonNull(o);
        return ((int) (this.value & MASK)) - ((int) (o.value & MASK));
    }

    /**
     * Warning, this value is based on the exact bytes interpreted as a signed integer.
     */
    @Override
    public int intValue() {
        return value;
    }

    @Override
    public long longValue() {
        return value;
    }

    @Override
    public float floatValue() {
        return longValue(); // rely on standard decimal -> floating point conversion
    }

    @Override
    public double doubleValue() {
        return longValue(); // rely on standard decimal -> floating point conversion
    }

    public BigInteger bigIntegerValue() {
        return BigInteger.valueOf(value);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        UnsignedInteger that = (UnsignedInteger) o;
        return value == that.value;
    }

    @Override
    public int hashCode() {
        return value;
    }
}
