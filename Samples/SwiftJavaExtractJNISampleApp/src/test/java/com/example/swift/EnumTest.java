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
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.util.Optional;

public class EnumTest {
    @Test
    void enumWithValueCases() {
        try (var arena = SwiftArena.ofConfined()) {
            EnumWithValueCases e = EnumWithValueCases.firstCase(48, arena);
            EnumWithValueCases.Case.FirstCase c = (EnumWithValueCases.Case.FirstCase) e.getCase();
            assertNotNull(c);
        }
    }

    @Test
    void enumWithBacktick() {
        try (var arena = SwiftArena.ofConfined()) {
            EnumWithBacktick e = EnumWithBacktick.default_(arena);
            assertTrue(e.getAsDefault().isPresent());
        }
    }

    @Test
    void enumWithCaseNameValue() {
        try (var arena = SwiftArena.ofConfined()) {
            var success = EnumWithCaseNameValue.Success.init("ok", arena);
            EnumWithCaseNameValue e = EnumWithCaseNameValue.success(success, arena);

            switch (e.getCase(arena)) {
            case EnumWithCaseNameValue.Case.Success(var s):
                assertEquals("ok", s.getMessage());
            }
        }
    }

    @Test
    void complexAssociatedValues_generic() {
        try (var arena = SwiftArena.ofConfined()) {
            var e = ComplexAssociatedValues.generic(
                    MyIDs.makeIntID(42L, arena),
                    MySwiftLibrary.makeIntGenericEnum(arena),
                    arena
            );
            assertEquals(
                    Optional.of("42"),
                    e.getAsGeneric(arena).map(v -> v.arg0().getDescription())
            );
        }
    }

    @Test
    void complexAssociatedValues_typealiasedGeneric() {
        try (var arena = SwiftArena.ofConfined()) {
            var e = ComplexAssociatedValues.typealiasedGeneric(
                    MyIDs.makeIntID(42L, arena),
                    arena
            );
            assertEquals(
                    Optional.of("42"),
                    e.getAsTypealiasedGeneric(arena).map(v -> v.id().getDescription())
            );
        }
    }

    @Test
    void complexAssociatedValues_array() {
        try (var arena = SwiftArena.ofConfined()) {
            var e = ComplexAssociatedValues.array(
                    List.of("Hello", "World").toArray(String[]::new),
                    arena
            );
            assertDoesNotThrow(() -> {
                var value = e.getAsArray().orElseThrow().arg0();
                assertArrayEquals(new String[]{"Hello", "World"}, value);
            });
        }
    }
}
