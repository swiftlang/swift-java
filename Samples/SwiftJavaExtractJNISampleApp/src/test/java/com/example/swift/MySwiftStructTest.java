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

package com.example.swift;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.ConfinedSwiftMemorySession;
import org.swift.swiftkit.core.SwiftArena;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftStructTest {
    @Test
    void init() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftStruct s = MySwiftStruct.init(1337, 42, arena);
            assertEquals(1337, s.getCapacity());
            assertEquals(42, s.getLen());
        }
    }

    @Test
    void init_optional() {
        try (var arena = SwiftArena.ofConfined()) {
            assertEquals(Optional.empty(), MySwiftStruct.init(false, arena));

            Optional<MySwiftStruct> optionalStruct = MySwiftStruct.init(true, arena);
            assertTrue(optionalStruct.isPresent());
            assertEquals(10, optionalStruct.get().getLen());
        }
    }

    @Test
    void getAndSetLen() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftStruct s = MySwiftStruct.init(1337, 42, arena);
            s.setLen(100);
            assertEquals(100, s.getLen());
        }
    }

    @Test
    void increaseCap() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftStruct s = MySwiftStruct.init(1337, 42, arena);
            long newCap = s.increaseCap(10);
            assertEquals(1347, newCap);
            assertEquals(1347, s.getCapacity());
        }
    }

    @Test
    void testSubscript() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftStruct s = MySwiftStruct.init(1337, 42, arena);
            long currentValue = s.getSubscript();
            s.setSubscript(66);
            assertEquals(0, currentValue);
            assertEquals(66, s.getSubscriptValue());
        }
    }

    @Test
    void testSubscriptWithParams() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftStruct s = MySwiftStruct.init(1337, 42, arena);
            long currentValue = s.getSubscript(1);
            s.setSubscript(1, 66);
            assertEquals(20, currentValue);
            assertEquals(66, s.getSubscriptArrayValue(1));
        }
    }
}