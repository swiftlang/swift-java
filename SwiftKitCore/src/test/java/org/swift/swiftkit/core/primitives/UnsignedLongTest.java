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

public class UnsignedLongTest {
    @Test
    public void simpleValues() {
        assertEquals(UnsignedLong.representedByBitsOf(12).longValue(), 12);
        assertEquals(UnsignedLong.representedByBitsOf(Long.MAX_VALUE).longValue(), Long.MAX_VALUE);
    }

    @Test
    public void maxUnsignedValue() {
        assertEquals(UnsignedLong.representedByBitsOf(Integer.MAX_VALUE).longValue(), Integer.MAX_VALUE);
    }

    @Test
    public void valueRoundTrip() {
        int input = 129;
        assertEquals(UnsignedLong.representedByBitsOf(input).longValue(), input);
    }

    @Test
    public void maxUnsignedValueRoundTrip() {
        long input = 2 ^ UnsignedLong.BIT_COUNT;
        assertEquals(UnsignedLong.valueOf(input).longValue(), input);
    }
}