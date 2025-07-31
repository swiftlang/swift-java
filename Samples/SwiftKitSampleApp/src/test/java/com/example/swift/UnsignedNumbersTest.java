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
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

public class UnsignedNumbersTest {
    @Test
    void take_uint32() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var c = MySwiftClass.init(1, 2, arena);
            c.takeUnsignedInt(128);
        }
    }

    @Test
    void take_uint64() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var c = MySwiftClass.init(1, 2, arena);
            c.takeUnsignedLong(Long.MAX_VALUE);
        }
    }
}
