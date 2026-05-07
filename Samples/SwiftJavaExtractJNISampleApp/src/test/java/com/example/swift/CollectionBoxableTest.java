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
import org.swift.swiftkit.core.collections.SwiftDictionaryMap;
import org.swift.swiftkit.core.collections.SwiftSet;

import static org.junit.jupiter.api.Assertions.*;

public class CollectionBoxableTest {
    @Test
    void intToFishDictionaryRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<Long, ReefFish> original = MySwiftLibrary.makeIntToFishDictionary(arena);
            assertEquals(2, original.size());
            assertEquals("salmon", original.get(1L).getName());
            assertEquals("clownfish", original.get(2L).getName());

            SwiftDictionaryMap<Long, ReefFish> roundtripped = MySwiftLibrary.intToFishDictionary(original, arena);
            assertEquals(2, roundtripped.size());
            assertEquals("salmon", roundtripped.get(1L).getName());
            assertEquals("clownfish", roundtripped.get(2L).getName());
        }
    }

    @Test
    void insertIntoIntToFishDictionary() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<Long, ReefFish> original = MySwiftLibrary.makeIntToFishDictionary(arena);
            ReefFish tuna = ReefFish.init("tuna", arena);

            SwiftDictionaryMap<Long, ReefFish> modified =
                MySwiftLibrary.insertIntoIntToFishDictionary(original, 3L, tuna, arena);

            assertEquals(3, modified.size());
            assertEquals("tuna", modified.get(3L).getName());
            assertEquals(2, original.size());
            assertNull(original.get(3L));
        }
    }

    @Test
    void fishSetRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<ReefFish> original = MySwiftLibrary.makeFishSet(arena);
            assertEquals(2, original.size());
            assertTrue(original.contains(ReefFish.init("salmon", arena)));
            assertTrue(original.contains(ReefFish.init("clownfish", arena)));

            SwiftSet<ReefFish> roundtripped = MySwiftLibrary.fishSet(original, arena);
            assertEquals(2, roundtripped.size());
            assertTrue(roundtripped.contains(ReefFish.init("salmon", arena)));
            assertTrue(roundtripped.contains(ReefFish.init("clownfish", arena)));
        }
    }

    @Test
    void insertIntoFishSet() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<ReefFish> original = MySwiftLibrary.makeFishSet(arena);
            ReefFish tuna = ReefFish.init("tuna", arena);

            SwiftSet<ReefFish> modified = MySwiftLibrary.insertIntoFishSet(original, tuna, arena);

            assertEquals(3, modified.size());
            assertTrue(modified.contains(tuna));
            assertEquals(2, original.size());
            assertFalse(original.contains(tuna));
        }
    }
}
