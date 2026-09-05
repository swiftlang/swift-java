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

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class UnsafeBufferPointerTest {
    @Test
    void nullMemorySegment_isEmptyTypedBuffer() {
        assertEquals(0, MySwiftLibrary.sumInt32Buffer(MemorySegment.NULL));
    }

    @Test
    void sumInt32Buffer() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment input = arena.allocateFrom(ValueLayout.JAVA_INT, new int[] {10, 20, 30, 40});

            assertEquals(100, MySwiftLibrary.sumInt32Buffer(input));
        }
    }

    @Test
    void sumInt32Buffer_empty() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment input = arena.allocate(0, ValueLayout.JAVA_INT.byteAlignment());

            assertEquals(0, MySwiftLibrary.sumInt32Buffer(input));
        }
    }

    @Test
    void returnInt32Buffer() {
        MemorySegment result = MySwiftLibrary.makeInt32Buffer();

        assertEquals(16, result.byteSize());
        assertEquals(10, result.get(ValueLayout.JAVA_INT, 0));
        assertEquals(40, result.get(ValueLayout.JAVA_INT, 12));
    }

    @Test
    void returnEmptyInt32Buffer() {
        assertEquals(0, MySwiftLibrary.makeEmptyInt32Buffer().byteSize());
    }

    @Test
    void returnMutableInt32Buffer() {
        MemorySegment result = MySwiftLibrary.makeMutableInt32Buffer();

        assertEquals(12, result.byteSize());
        assertEquals(5, result.get(ValueLayout.JAVA_INT, 0));
        assertEquals(15, result.get(ValueLayout.JAVA_INT, 8));
    }

    @Test
    void mutableInt32Buffer_isInitialized() {
        MemorySegment buffer = MySwiftLibrary.makeMutableInt32Buffer();

        assertEquals(5, buffer.get(ValueLayout.JAVA_INT, 0));
        assertEquals(10, buffer.get(ValueLayout.JAVA_INT, 4));
        assertEquals(15, buffer.get(ValueLayout.JAVA_INT, 8));
    }

    @Test
    void incrementMutableInt32Buffer_modifiesElements() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment buffer = arena.allocateFrom(ValueLayout.JAVA_INT, new int[] {5, 10, 15});

            MySwiftLibrary.incrementMutableInt32Buffer(buffer);

            assertEquals(6, buffer.get(ValueLayout.JAVA_INT, 0));
            assertEquals(11, buffer.get(ValueLayout.JAVA_INT, 4));
            assertEquals(16, buffer.get(ValueLayout.JAVA_INT, 8));
        }
    }
}
