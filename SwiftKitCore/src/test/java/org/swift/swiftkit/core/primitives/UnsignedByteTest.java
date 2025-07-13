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

public class UnsignedByteTest {
    @Test
    public void simpleValues() {
        assertEquals(UnsignedByte.representedByBitsOf((byte) 12).longValue(), 12);
    }

    @Test
    public void maxUnsignedValue() {
        assertEquals(UnsignedByte.representedByBitsOf(Byte.MAX_VALUE).longValue(), Byte.MAX_VALUE);
    }

    @Test
    public void maxUnsignedValueRoundTrip() {
        long input = 2 ^ UnsignedByte.BIT_COUNT;
        assertEquals(UnsignedByte.valueOf(input).longValue(), input);
    }
}