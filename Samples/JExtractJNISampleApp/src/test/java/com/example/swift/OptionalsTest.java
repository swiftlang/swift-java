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

import java.util.Optional;
import java.util.OptionalInt;

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
}