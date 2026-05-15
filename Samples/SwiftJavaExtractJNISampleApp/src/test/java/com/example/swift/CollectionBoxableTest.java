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

import java.util.Arrays;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

public class CollectionBoxableTest {
    @Test
    void intToFishDictionaryRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<Long, Fish> original = MySwiftLibrary.makeIntToFishDictionary(arena);
            assertEquals(2, original.size());
            assertEquals("salmon", original.get(1L).getName());
            assertEquals("clownfish", original.get(2L).getName());

            SwiftDictionaryMap<Long, Fish> roundtripped = MySwiftLibrary.intToFishDictionary(original, arena);
            assertEquals(2, roundtripped.size());
            assertEquals("salmon", roundtripped.get(1L).getName());
            assertEquals("clownfish", roundtripped.get(2L).getName());
        }
    }

    @Test
    void fishSetRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<Fish> original = MySwiftLibrary.makeFishSet(arena);
            assertEquals(2, original.size());
            assertTrue(original.contains(Fish.init("salmon", arena)));
            assertTrue(original.contains(Fish.init("clownfish", arena)));

            SwiftSet<Fish> roundtripped = MySwiftLibrary.fishSet(original, arena);
            assertEquals(2, roundtripped.size());
            assertTrue(roundtripped.contains(Fish.init("salmon", arena)));
            assertTrue(roundtripped.contains(Fish.init("clownfish", arena)));
        }
    }

    @Test
    void makeMyIDToFish() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<MyID<Long>, Fish> dict = MySwiftLibrary.makeMyIDToFish(arena);
            assertEquals(2, dict.size());

            MyID<Long> salmonId = MyIDs.makeIntID(0, arena);
            MyID<Long> clownfishId = MyIDs.makeIntID(1, arena);
            MyID<Long> unknownId = MyIDs.makeIntID(-100, arena);

            assertTrue(dict.containsKey(salmonId));
            assertTrue(dict.containsKey(clownfishId));
            assertFalse(dict.containsKey(unknownId));
            assertEquals("salmon", dict.get(salmonId).getName());
            assertEquals("clownfish", dict.get(clownfishId).getName());
        }
    }

    @Test
    void makeSpecializedGenericTypeSet() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftSet<Box<Fish>> set = MySwiftLibrary.makeSpecializedGenericTypeSet(arena);

            assertEquals(
                    set.stream()
                            .map(Box::getCount)
                            .collect(Collectors.toSet()),
                    Set.of(2L, 3L)
            );
        }
    }

    @Test
    void makeSetInDictionary() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<String, SwiftSet<Integer>> dict = MySwiftLibrary.makeSetInDictionary(arena);
            assertEquals(Set.of(0, 2, 4), dict.get("even").toJavaSet());
            assertNull(dict.get("unknown"));
        }
    }

    @Test
    void fishArrayDictionaryRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<String, Fish[]> original = MySwiftLibrary.makeFishArrayDictionary(arena);
            assertArrayEquals(new String[] {"clownfish", "blue tang"}, fishNames(original.get("reef")));
            assertArrayEquals(new String[] {"salmon"}, fishNames(original.get("river")));

            SwiftDictionaryMap<String, Fish[]> roundtripped = MySwiftLibrary.fishArrayDictionary(original, arena);
            assertArrayEquals(new String[] {"clownfish", "blue tang"}, fishNames(roundtripped.get("reef")));
            assertArrayEquals(new String[] {"salmon"}, fishNames(roundtripped.get("river")));
        }
    }

    @Test
    void optionalFishDictionaryRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftDictionaryMap<String, Optional<Fish>> original = MySwiftLibrary.makeOptionalFishDictionary(arena);
            assertDoesNotThrow(() -> {
                var value = original.get("reef").orElseThrow();
                assertEquals("clownfish", value.getName());
            });
            assertDoesNotThrow(() -> {
                assertTrue(original.get("empty").isEmpty());
            });

            SwiftDictionaryMap<String, Optional<Fish>> roundtripped = MySwiftLibrary.optionalFishDictionary(original, arena);
            assertDoesNotThrow(() -> {
                var value = roundtripped.get("reef").orElseThrow();
                assertEquals("clownfish", value.getName());
            });
            assertDoesNotThrow(() -> {
                assertTrue(roundtripped.get("empty").isEmpty());
            });
        }
    }

    private static String[] fishNames(Fish[] fish) {
        return Arrays.stream(fish)
                .map(Fish::getName)
                .toArray(String[]::new);
    }
}
