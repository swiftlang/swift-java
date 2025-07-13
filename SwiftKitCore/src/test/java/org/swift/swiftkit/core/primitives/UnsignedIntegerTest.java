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

package org.swift.swiftkit.core.primitives;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class UnsignedIntegerTest {
    @Test
    public void simpleValues() {
        assertEquals(UnsignedInteger.representedByBitsOf(12).intValue(), 12);
        // signed "max" easily fits in an unsigned integer
        assertEquals(UnsignedInteger.representedByBitsOf(Integer.MAX_VALUE).intValue(), Integer.MAX_VALUE);
    }

    @Test
    public void maxUnsignedValue() {
        assertEquals(UnsignedInteger.representedByBitsOf(Integer.MAX_VALUE).intValue(), Integer.MAX_VALUE);
    }

    @Test
    public void outOfRangeLongValue() {
        var exception = assertThrows(Exception.class, () -> UnsignedInteger.valueOf(Long.MAX_VALUE).intValue());
        assertTrue(exception instanceof UnsignedOverflowException);
    }

    @Test
    public void valueRoundTrip() {
        int input = 129;
        assertEquals(UnsignedInteger.representedByBitsOf(input).intValue(), input);
    }

    @Test
    public void maxUnsignedValueRoundTrip() {
        long input = 2 ^ UnsignedInteger.BIT_COUNT;
        assertEquals(UnsignedInteger.valueOf(input).longValue(), input);
    }
}