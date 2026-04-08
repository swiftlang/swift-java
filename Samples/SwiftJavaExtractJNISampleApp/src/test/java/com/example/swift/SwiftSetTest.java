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

import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.collections.SwiftSet;
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class SwiftSetTest {
    @Test
    void makeStringSet() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<String> set = MySwiftLibrary.makeStringSet(arena);
            assertEquals(2, set.size());
            assertTrue(set.contains("hello"));
            assertTrue(set.contains("world"));
            assertFalse(set.contains("missing"));
        }
    }

    @Test
    void stringSetRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<String> original = MySwiftLibrary.makeStringSet(arena);
            SwiftSet<String> roundtripped = MySwiftLibrary.stringSet(original, arena);
            assertEquals(original.size(), roundtripped.size());
            assertTrue(roundtripped.contains("hello"));
            assertTrue(roundtripped.contains("world"));
        }
    }

    @Test
    void insertIntoStringSet() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<String> original = MySwiftLibrary.makeStringSet(arena);
            assertEquals(2, original.size());

            // Insert a new element by passing the set through Swift
            SwiftSet<String> modified =
                MySwiftLibrary.insertIntoStringSet(original, "swift", arena);

            // The modified set has the new element
            assertEquals(3, modified.size());
            assertTrue(modified.contains("hello"));
            assertTrue(modified.contains("world"));
            assertTrue(modified.contains("swift"));

            // The original set is unchanged (Swift value semantics - it's a copy)
            assertEquals(2, original.size());
            assertFalse(original.contains("swift"));
        }
    }

    @Test
    void toJavaSet() {
        Set<String> javaSet;
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<String> set = MySwiftLibrary.makeStringSet(arena);
            javaSet = set.toJavaSet();

            // The copy has the same contents as the original
            assertEquals(2, javaSet.size());
            assertTrue(javaSet.contains("hello"));
            assertTrue(javaSet.contains("world"));
            assertFalse(javaSet.contains("missing"));

            // It's a plain HashSet, not the native-backed set
            assertInstanceOf(HashSet.class, javaSet);
        }

        // The Java set copy survives arena closure
        assertEquals(2, javaSet.size());
        assertTrue(javaSet.contains("hello"));
        assertTrue(javaSet.contains("world"));
    }

    // ==== Swift Set<Int32> -> Java Set<Integer> tests ====

    @Test
    void makeIntegerSet() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<Integer> set = MySwiftLibrary.makeIntegerSet(arena);
            assertEquals(3, set.size());
            assertTrue(set.contains(1));
            assertTrue(set.contains(2));
            assertTrue(set.contains(3));
            assertFalse(set.contains(42));
        }
    }

    @Test
    void integerSetRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<Integer> original = MySwiftLibrary.makeIntegerSet(arena);
            SwiftSet<Integer> roundtripped = MySwiftLibrary.integerSet(original, arena);
            assertEquals(original.size(), roundtripped.size());
            assertTrue(roundtripped.contains(1));
            assertTrue(roundtripped.contains(2));
            assertTrue(roundtripped.contains(3));
        }
    }

    // ==== Swift Set<Int> -> Java Set<Long> tests ====

    @Test
    void makeLongSet() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<Long> set = MySwiftLibrary.makeLongSet(arena);
            assertEquals(3, set.size());
            assertTrue(set.contains(10L));
            assertTrue(set.contains(20L));
            assertTrue(set.contains(30L));
            assertFalse(set.contains(99L));
        }
    }

    @Test
    void longSetRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<Long> original = MySwiftLibrary.makeLongSet(arena);
            SwiftSet<Long> roundtripped = MySwiftLibrary.longSet(original, arena);
            assertEquals(original.size(), roundtripped.size());
            assertTrue(roundtripped.contains(10L));
            assertTrue(roundtripped.contains(20L));
            assertTrue(roundtripped.contains(30L));
        }
    }
}
