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
import org.swift.swiftkit.core.SwiftArena;

import java.util.Optional;
import java.util.OptionalDouble;
import java.util.OptionalInt;
import java.util.OptionalLong;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class OptionalsTest {
    @Test
    void optionalBool() {
        assertEquals(Optional.empty(), MySwiftLibrary.optionalBool(Optional.empty()));
        assertEquals(Optional.of(true), MySwiftLibrary.optionalBool(Optional.of(true)));
    }

    @Test
    void optionalByte() {
        assertEquals(Optional.empty(), MySwiftLibrary.optionalByte(Optional.empty()));
        assertEquals(Optional.of((byte) 1) , MySwiftLibrary.optionalByte(Optional.of((byte) 1)));
    }

    @Test
    void optionalChar() {
        assertEquals(Optional.empty(), MySwiftLibrary.optionalChar(Optional.empty()));
        assertEquals(Optional.of((char) 42), MySwiftLibrary.optionalChar(Optional.of((char) 42)));
    }

    @Test
    void optionalShort() {
        assertEquals(Optional.empty(), MySwiftLibrary.optionalShort(Optional.empty()));
        assertEquals(Optional.of((short) -250), MySwiftLibrary.optionalShort(Optional.of((short) -250)));
    }

    @Test
    void optionalInt() {
        assertEquals(OptionalInt.empty(), MySwiftLibrary.optionalInt(OptionalInt.empty()));
        assertEquals(OptionalInt.of(999), MySwiftLibrary.optionalInt(OptionalInt.of(999)));
    }

    @Test
    void optionalLong() {
        assertEquals(OptionalLong.empty(), MySwiftLibrary.optionalLong(OptionalLong.empty()));
        assertEquals(OptionalLong.of(999), MySwiftLibrary.optionalLong(OptionalLong.of(999)));
    }

    @Test
    void optionalFloat() {
        assertEquals(Optional.empty(), MySwiftLibrary.optionalFloat(Optional.empty()));
        assertEquals(Optional.of(3.14f), MySwiftLibrary.optionalFloat(Optional.of(3.14f)));
    }

    @Test
    void optionalDouble() {
        assertEquals(OptionalDouble.empty(), MySwiftLibrary.optionalDouble(OptionalDouble.empty()));
        assertEquals(OptionalDouble.of(2.718), MySwiftLibrary.optionalDouble(OptionalDouble.of(2.718)));
    }

    @Test
    void optionalString() {
        assertEquals(Optional.empty(), MySwiftLibrary.optionalString(Optional.empty()));
        assertEquals(Optional.of("Hello Swift!"), MySwiftLibrary.optionalString(Optional.of("Hello Swift!")));
    }

    @Test
    void optionalClass() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftClass c = MySwiftClass.init(arena);
            assertEquals(Optional.empty(), MySwiftLibrary.optionalClass(Optional.empty(), arena));
            Optional<MySwiftClass> optionalClass = MySwiftLibrary.optionalClass(Optional.of(c), arena);
            assertTrue(optionalClass.isPresent());
            assertEquals(c.getX(), optionalClass.get().getX());
        }
    }

    @Test
    void optionalJavaKitLong() {
        assertEquals(OptionalLong.empty(), MySwiftLibrary.optionalJavaKitLong(Optional.empty()));
        assertEquals(OptionalLong.of(99L), MySwiftLibrary.optionalJavaKitLong(Optional.of(99L)));
    }

    @Test
    void multipleOptionals() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftClass c = MySwiftClass.init(arena);
            OptionalLong result = MySwiftLibrary.multipleOptionals(
                    Optional.of((byte) 1),
                    Optional.of((short) 42),
                    OptionalInt.of(50),
                    OptionalLong.of(1000L),
                    Optional.of("42"),
                    Optional.of(c),
                    Optional.of(true)
            );
            assertEquals(result, OptionalLong.of(1L));
        }
    }
}