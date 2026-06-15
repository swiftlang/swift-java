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

import java.util.HashSet;
import java.util.List;

@SuppressWarnings({"AssertBetweenInconvertibleTypes", "EqualsWithItself"})
public class HashableTest {
    @Test
    void valueTypeEquals() {
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
    void referenceTypeEquals() {
        try (var arena = SwiftArena.ofConfined()) {
            var a = HashableClass.init(42, arena);
            var b = HashableSubclass.init(42, arena);
            var c = HashableSubclass.init(0, arena);
            assertEquals(a, b);
            assertEquals(b, a);
            assertEquals(b, b);
            assertNotEquals(a, c);
            assertNotEquals(b, c);
        }
    }

    @Test
    void hashSetValueType() {
        try (var arena = SwiftArena.ofConfined()) {
            var a = MyIDs.makeIntID(42, arena);
            var b = MyIDs.makeIntID(42, arena);
            var c = MyIDs.makeIntID(0, arena);
            var set = new HashSet<>(List.of(
                    a, b
            ));
            assertTrue(set.contains(a));
            assertTrue(set.contains(b));
            assertFalse(set.contains(c));
            assertEquals(1, set.size());
        }
    }

    @Test
    void nonEquatableReferenceTypeFallsBackToIdentity() {
        // MySwiftClass does not conform to Swift's `Equatable`, so the JNI
        // bridge should fall back to identity equality.
        try (var arena = SwiftArena.ofConfined()) {
            var a = MySwiftClass.init(42, 1, arena);
            var b = MySwiftClass.init(42, 1, arena);
            assertEquals(a, a);
            assertEquals(b, b);
            // Different instances with equal field values must NOT be equal,
            // since the type is not Equatable
            assertNotEquals(a, b);
            assertNotEquals(b, a);
            assertNotEquals(a, "foo");
        }
    }

    @Test
    void nonEquatableReferenceTypeHashSetUsesIdentity() {
        try (var arena = SwiftArena.ofConfined()) {
            var a = MySwiftClass.init(42, 1, arena);
            var b = MySwiftClass.init(42, 1, arena);
            var set = new HashSet<>(List.of(a, b));
            assertTrue(set.contains(a));
            assertTrue(set.contains(b));
            // Two distinct instances of a non-Equatable class are distinct
            // entries in the set
            assertEquals(2, set.size());
        }
    }

    @Test
    void hashSetReferenceType() {
        try (var arena = SwiftArena.ofConfined()) {
            var a = HashableClass.init(42, arena);
            var b = HashableClass.init(42, arena);
            var c = HashableSubclass.init(42, arena);
            var d = HashableSubclass.init(0, arena);
            var set = new HashSet<>(List.of(
                    a, b, c
            ));
            assertTrue(set.contains(a));
            assertTrue(set.contains(b));
            assertTrue(set.contains(c));
            assertFalse(set.contains(d));
            assertEquals(1, set.size());
        }
    }
}
