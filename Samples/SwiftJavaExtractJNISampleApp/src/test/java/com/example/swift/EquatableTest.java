//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
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
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

@SuppressWarnings({"AssertBetweenInconvertibleTypes", "EqualsWithItself"})
public class EquatableTest {
    @Test
    void genericStructType() {
        try (var arena = SwiftArena.ofConfined()) {
            var a = MyIDs.makeIntID(42, arena);
            var b = MyIDs.makeIntID(42, arena);
            var c = MyIDs.makeIntID(0, arena);
            var d = MyIDs.makeStringID("42", arena);
            assertEquals(a, a);
            assertEquals(a, b);
            assertNotEquals(a, c);
            assertNotEquals(a, d);
            assertNotEquals("foo", a);
        }
    }

    @Test
    void classType() {
        try (var arena = SwiftArena.ofConfined()) {
            var a = EquatableClass.init(42, arena);
            var b = EquatableSubclass.init(42, arena);
            var c = EquatableSubclass.init(0, arena);
            assertEquals(a, b);
            assertEquals(b, a);
            assertEquals(b, b);
            assertNotEquals(a, c);
            assertNotEquals(b, c);
        }
    }
}
