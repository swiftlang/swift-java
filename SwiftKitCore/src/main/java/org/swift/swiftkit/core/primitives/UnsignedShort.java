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
 *  * Represents an 32-bit unsigned integer, with a value between 0 and (@{@code 2^16 - 1}).
 *
 * <p> Equivalent to the {@code UInt16} Swift type.
 */
public final class UnsignedShort extends Number implements Comparable<UnsignedShort> {

    public final static UnsignedShort ZERO = representedByBitsOf((short) 0);
    public final static UnsignedShort MAX_VALUE = representedByBitsOf((short) -1);
    public final static long MASK = 0xffffL;
    public final static long BIT_COUNT = 16;

    final short value;

    private UnsignedShort(short bits) {
        this.value = bits;
    }

    /**
     * Accept a signed Java @{code int} value, and interpret it as-if it was an unsigned value.
     * In other words, do not interpret the negative bit as "negative", but as part of the unsigned integers value.
     *
     * @param bits bit value to store in this unsigned integer
     * @return unsigned integer representation of the passed in value
     */
    public static UnsignedShort representedByBitsOf(short bits) {
        return new UnsignedShort(bits);
    }

    public static UnsignedShort valueOf(long value) throws UnsignedOverflowException {
        if ((value & UnsignedShort.MASK) != value) {
            throw new UnsignedOverflowException(String.valueOf(value), UnsignedShort.class);
        }
        return representedByBitsOf((short) value);
    }

    @Override
    public int compareTo(UnsignedShort o) {
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
        UnsignedShort that = (UnsignedShort) o;
        return value == that.value;
    }

    @Override
    public int hashCode() {
        return value;
    }
}
