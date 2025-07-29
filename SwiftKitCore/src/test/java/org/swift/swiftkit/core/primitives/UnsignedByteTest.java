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
        assertEquals(UnsignedBytes.toInt((byte) 12), 12);
    }

    @Test
    public void maxUnsignedValue() {
        assertEquals(UnsignedBytes.toInt(Byte.MAX_VALUE), Byte.MAX_VALUE);
    }
}