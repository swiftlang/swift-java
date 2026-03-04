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
import org.swift.swiftkit.core.NativeSwiftDictionaryMap;
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class DictionariesTest {
    @Test
    void makeStringToLongDictionary() {
        try (var arena = SwiftArena.ofConfined()) {
            NativeSwiftDictionaryMap<String, Long> dict = MySwiftLibrary.makeStringToLongDictionary(arena);
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
            NativeSwiftDictionaryMap<String, Long> original = MySwiftLibrary.makeStringToLongDictionary(arena);
            NativeSwiftDictionaryMap<String, Long> roundtripped = MySwiftLibrary.stringToLongDictionary(original, arena);
            assertEquals(original.size(), roundtripped.size());
            assertEquals(original.get("hello"), roundtripped.get("hello"));
            assertEquals(original.get("world"), roundtripped.get("world"));
        }
    }
}
