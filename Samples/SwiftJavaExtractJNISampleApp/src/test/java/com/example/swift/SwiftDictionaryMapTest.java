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

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.collections.SwiftDictionaryMap;
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class SwiftDictionaryMapTest {
    @Test
    void makeStringToLongDictionary() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<String, Long> dict = MySwiftLibrary.makeStringToLongDictionary(arena);
            assertEquals(2, dict.size());
            assertEquals(1L, dict.get("hello"));
            assertEquals(2L, dict.get("world"));
            assertTrue(dict.containsKey("hello"));
            assertFalse(dict.containsKey("missing"));
            assertNull(dict.get("missing"));
        }
    }

    @Test
    void stringToLongDictionaryRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<String, Long> original = MySwiftLibrary.makeStringToLongDictionary(arena);
            SwiftDictionaryMap<String, Long> roundtripped = MySwiftLibrary.stringToLongDictionary(original, arena);
            assertEquals(original.size(), roundtripped.size());
            assertEquals(original.get("hello"), roundtripped.get("hello"));
            assertEquals(original.get("world"), roundtripped.get("world"));
        }
    }

    @Test
    void insertIntoStringToLongDictionary() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<String, Long> original = MySwiftLibrary.makeStringToLongDictionary(arena);
            assertEquals(2, original.size());

            // Insert a new key by passing the dictionary through Swift
            SwiftDictionaryMap<String, Long> modified =
                MySwiftLibrary.insertIntoStringToLongDictionary(original, "swift", 42L, arena);

            // The modified dictionary has the new key
            assertEquals(3, modified.size());
            assertEquals(1L, modified.get("hello"));
            assertEquals(2L, modified.get("world"));
            assertEquals(42L, modified.get("swift"));

            // The original dictionary is unchanged (Swift value semantics - it's a copy)
            assertEquals(2, original.size());
            assertNull(original.get("swift"));
        }
    }

    @Test
    void toJavaMap() {
        Map<String, Long> javaMap;
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<String, Long> dict = MySwiftLibrary.makeStringToLongDictionary(arena);
            javaMap = dict.toJavaMap();

            // The copy has the same contents as the original
            assertEquals(2, javaMap.size());
            assertEquals(1L, javaMap.get("hello"));
            assertEquals(2L, javaMap.get("world"));
            assertTrue(javaMap.containsKey("hello"));
            assertFalse(javaMap.containsKey("missing"));

            // It's a plain HashMap, not the native-backed map
            assertInstanceOf(HashMap.class, javaMap);
        }

        // The Java map copy survives arena closure
        assertEquals(2, javaMap.size());
        assertEquals(1L, javaMap.get("hello"));
        assertEquals(2L, javaMap.get("world"));
    }
}
