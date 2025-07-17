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

import static org.junit.jupiter.api.Assertions.assertEquals;

public class UnsignedShortTest {
    @Test
    public void simpleValues() {
        assertEquals(UnsignedShort.representedByBitsOf((short) 12).longValue(), 12);
    }

    @Test
    public void maxUnsignedValue() {
        assertEquals(UnsignedShort.representedByBitsOf(Short.MAX_VALUE).longValue(), Short.MAX_VALUE);
    }

    @Test
    public void maxUnsignedValueRoundTrip() {
        long input = 2 ^ UnsignedShort.BIT_COUNT;
        assertEquals(UnsignedShort.valueOf(input).longValue(), input);
    }
}