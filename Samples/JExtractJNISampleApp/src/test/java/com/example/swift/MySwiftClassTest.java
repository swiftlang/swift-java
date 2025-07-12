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

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftClassTest {
    @Test
    void init_noParameters() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(arena);
            assertNotNull(c);
        }
    }

    @Test
    void init_withParameters() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(1337, 42, arena);
            assertNotNull(c);
        }
    }

    @Test
    void sum() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);
            assertEquals(30, c.sum());
        }
    }

    @Test
    void xMultiplied() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);
            assertEquals(200, c.xMultiplied(10));
        }
    }

    @Test
    void throwingFunction() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);
            Exception exception = assertThrows(Exception.class, () -> c.throwingFunction());

            assertEquals("swiftError", exception.getMessage());
        }
    }

    @Test
    void constant() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);
            assertEquals(100, c.getConstant());
        }
    }

    @Test
    void mutable() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);
            assertEquals(0, c.getMutable());
            c.setMutable(42);
            assertEquals(42, c.getMutable());
        }
    }

    @Test
    void product() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);
            assertEquals(200, c.getProduct());
        }
    }

    @Test
    void throwingVariable() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);

            Exception exception = assertThrows(Exception.class, () -> c.getThrowingVariable());

            assertEquals("swiftError", exception.getMessage());
        }
    }

    @Test
    void mutableDividedByTwo() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            MySwiftClass c = MySwiftClass.init(20, 10, arena);
            assertEquals(0, c.getMutableDividedByTwo());
            c.setMutable(20);
            assertEquals(10, c.getMutableDividedByTwo());
            c.setMutableDividedByTwo(5);
            assertEquals(10, c.getMutable());
        }
    }


}