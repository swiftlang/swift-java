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
public final class UnsignedNumbers {

    public static byte toPrimitive(UnsignedByte value) {
        return value.value;
    }

    public static short toPrimitive(UnsignedShort value) {
        return value.value;
    }

    public static int toPrimitive(UnsignedInteger value) {
        return value.value;
    }

    public static long toPrimitive(UnsignedLong value) {
        return value.value;
    }
}