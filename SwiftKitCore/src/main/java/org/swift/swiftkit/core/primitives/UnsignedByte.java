/*
 * Copyright (C) 2011 The Guava Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */

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

import org.swift.swiftkit.core.annotations.Nullable;

import java.math.BigInteger;

import static org.swift.swiftkit.core.Preconditions.checkArgument;
import static org.swift.swiftkit.core.Preconditions.checkNotNull;
import static org.swift.swiftkit.core.primitives.UnsignedInts.*;

/**
 * A wrapper class for unsigned {@code byte} values, supporting arithmetic operations.
 *
 * <p>This type is a "safe" wrapper around an unsigned byte. It is intended for source generation where
 * the generated sources should be intentional about the accepted and returned types, in order to avoid
 * accidentally mistreating values as negative
 *
 * <p>In some cases, when speed is more important than code readability, it may be faster simply to
 * treat primitive {@code int} values as unsigned, using the methods from {@link UnsignedInts}.
 */
public final class UnsignedByte extends Number implements Comparable<UnsignedByte> {
  public static final UnsignedByte ZERO = fromIntBits(0);
  public static final UnsignedByte ONE = fromIntBits(1);
  public static final UnsignedByte MAX_VALUE = fromIntBits(-1);

  private final int value;

  private UnsignedByte(int value) {
    // GWT doesn't consistently overflow values to make them 32-bit, so we need to force it.
    this.value = value & 0xffffffff;
  }

  /**
   * Returns an {@code UnsignedInteger} corresponding to a given bit representation. The argument is
   * interpreted as an unsigned 32-bit value. Specifically, the sign bit of {@code bits} is
   * interpreted as a normal bit, and all other bits are treated as usual.
   *
   * <p>If the argument is nonnegative, the returned result will be equal to {@code bits},
   * otherwise, the result will be equal to {@code 2^32 + bits}.
   *
   * <p>To represent unsigned decimal constants, consider {@link #valueOf(long)} instead.
   *
   * @since 14.0
   */
  public static UnsignedByte fromIntBits(int bits) {
    return new UnsignedByte(bits);
  }

  /**
   * Returns an {@code UnsignedInteger} that is equal to {@code value}, if possible. The inverse
   * operation of {@link #longValue()}.
   */
  public static UnsignedByte valueOf(long value) {
    checkArgument(
        (value & INT_MASK) == value,
        "value (%s) is outside the range for an unsigned integer value",
        value);
    return fromIntBits((int) value);
  }

  /**
   * Returns a {@code UnsignedInteger} representing the same value as the specified {@link
   * BigInteger}. This is the inverse operation of {@link #bigIntegerValue()}.
   *
   * @throws IllegalArgumentException if {@code value} is negative or {@code value >= 2^32}
   */
  public static UnsignedByte valueOf(BigInteger value) {
    checkNotNull(value);
    checkArgument(
        value.signum() >= 0 && value.bitLength() <= Integer.SIZE,
        "value (%s) is outside the range for an unsigned integer value",
        value);
    return fromIntBits(value.intValue());
  }

  /**
   * Returns an {@code UnsignedInteger} holding the value of the specified {@code String}, parsed as
   * an unsigned {@code int} value.
   *
   * @throws NumberFormatException if the string does not contain a parsable unsigned {@code int}
   *     value
   */
  public static UnsignedByte valueOf(String string) {
    return valueOf(string, 10);
  }

  /**
   * Returns an {@code UnsignedInteger} holding the value of the specified {@code String}, parsed as
   * an unsigned {@code int} value in the specified radix.
   *
   * @throws NumberFormatException if the string does not contain a parsable unsigned {@code int}
   *     value
   */
  public static UnsignedByte valueOf(String string, int radix) {
    return fromIntBits(UnsignedInts.parseUnsignedInt(string, radix));
  }

  /**
   * Returns the result of adding this and {@code val}. If the result would have more than 32 bits,
   * returns the low 32 bits of the result.
   *
   * @since 14.0
   */
  public UnsignedByte plus(UnsignedByte val) {
    return fromIntBits(this.value + checkNotNull(val).value);
  }

  /**
   * Returns the result of subtracting this and {@code val}. If the result would be negative,
   * returns the low 32 bits of the result.
   *
   * @since 14.0
   */
  public UnsignedByte minus(UnsignedByte val) {
    return fromIntBits(value - checkNotNull(val).value);
  }

  /**
   * Returns the result of multiplying this and {@code val}. If the result would have more than 32
   * bits, returns the low 32 bits of the result.
   *
   * @since 14.0
   */
  public UnsignedByte times(UnsignedByte val) {
    // TODO(lowasser): make this GWT-compatible
    return fromIntBits(value * checkNotNull(val).value);
  }

  /**
   * Returns the result of dividing this by {@code val}.
   *
   * @throws ArithmeticException if {@code val} is zero
   * @since 14.0
   */
  public UnsignedByte dividedBy(UnsignedByte val) {
    return fromIntBits(UnsignedInts.divide(value, checkNotNull(val).value));
  }

  /**
   * Returns this mod {@code val}.
   *
   * @throws ArithmeticException if {@code val} is zero
   * @since 14.0
   */
  public UnsignedByte mod(UnsignedByte val) {
    return fromIntBits(UnsignedInts.remainder(value, checkNotNull(val).value));
  }

  /**
   * Returns the value of this {@code UnsignedInteger} as an {@code int}. This is an inverse
   * operation to {@link #fromIntBits}.
   *
   * <p>Note that if this {@code UnsignedInteger} holds a value {@code >= 2^31}, the returned value
   * will be equal to {@code this - 2^32}.
   */
  @Override
  public int intValue() {
    return value;
  }

  /** Returns the value of this {@code UnsignedInteger} as a {@code long}. */
  @Override
  public long longValue() {
    return toLong(value);
  }

  /**
   * Returns the value of this {@code UnsignedInteger} as a {@code float}, analogous to a widening
   * primitive conversion from {@code int} to {@code float}, and correctly rounded.
   */
  @Override
  public float floatValue() {
    return longValue();
  }

  /**
   * Returns the value of this {@code UnsignedInteger} as a {@code double}, analogous to a widening
   * primitive conversion from {@code int} to {@code double}, and correctly rounded.
   */
  @Override
  public double doubleValue() {
    return longValue();
  }

  /** Returns the value of this {@code UnsignedInteger} as a {@link BigInteger}. */
  public BigInteger bigIntegerValue() {
    return BigInteger.valueOf(longValue());
  }

  /**
   * Compares this unsigned integer to another unsigned integer. Returns {@code 0} if they are
   * equal, a negative number if {@code this < other}, and a positive number if {@code this >
   * other}.
   */
  @Override
  public int compareTo(UnsignedByte other) {
    checkNotNull(other);
    return compare(value, other.value);
  }

  @Override
  public int hashCode() {
    return value;
  }

  @Override
  public boolean equals(@Nullable Object obj) {
    if (obj instanceof UnsignedByte) {
      UnsignedByte other = (UnsignedByte) obj;
      return value == other.value;
    }
    return false;
  }

  /** Returns a string representation of the {@code UnsignedInteger} value, in base 10. */
  @Override
  public String toString() {
    return toString(10);
  }

  /**
   * Returns a string representation of the {@code UnsignedInteger} value, in base {@code radix}. If
   * {@code radix < Character.MIN_RADIX} or {@code radix > Character.MAX_RADIX}, the radix {@code
   * 10} is used.
   */
  public String toString(int radix) {
    return UnsignedInts.toString(value, radix);
  }
}
