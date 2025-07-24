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

package com.example.swift;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.primitives.*;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class UnsignedTest {
    @Test
    void take_unsigned_int32() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var c = MySwiftClass.init(1, 2, arena);
            c.takeUnsignedInt(UnsignedInteger.valueOf(128));
        }
    }

    @Test
    void take_uint8() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var c = MySwiftClass.init(1, 2, arena);
            byte got = c.takeUnsignedByte(UnsignedByte.valueOf(200)); // FIXME: should return UnsignedByte
            assertEquals(UnsignedByte.representedByBitsOf(got).intValue(), got);
        }
    }
}
