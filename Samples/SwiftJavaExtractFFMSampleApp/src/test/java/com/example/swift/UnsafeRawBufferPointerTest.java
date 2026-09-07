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

public class UnsafeRawBufferPointerTest {
    @Test
    void sumOfBytes() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment input = arena.allocateFrom(ValueLayout.JAVA_BYTE, new byte[] {1, 2, 3, 4, 5});

            assertEquals(15, MySwiftLibrary.sumOfBytes(input));
        }
    }

    @Test
    void sumOfBytes_empty() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment input = arena.allocate(0, 1);

            assertEquals(0, MySwiftLibrary.sumOfBytes(input));
        }
    }

    @Test
    void bufferCount() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment input = arena.allocateFrom(ValueLayout.JAVA_BYTE, new byte[] {10, 20, 30, 40});

            assertEquals(4, MySwiftLibrary.bufferCount(input));
        }
    }

    @Test
    void bufferCount_empty() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment input = arena.allocate(0, 1);

            assertEquals(0, MySwiftLibrary.bufferCount(input));
        }
    }

    @Test
    void returnRawBuffer() {
        MemorySegment result = MySwiftLibrary.makeRawBuffer();

        assertEquals(4, result.byteSize());
        assertEquals(10, result.get(ValueLayout.JAVA_BYTE, 0));
        assertEquals(40, result.get(ValueLayout.JAVA_BYTE, 3));
    }

    @Test
    void returnEmptyRawBuffer() {
        assertEquals(0, MySwiftLibrary.makeEmptyRawBuffer().byteSize());
    }

    @Test
    void returnMutableRawBuffer() {
        MemorySegment result = MySwiftLibrary.makeMutableRawBuffer();

        assertEquals(3, result.byteSize());
        assertEquals(5, result.get(ValueLayout.JAVA_BYTE, 0));
        assertEquals(15, result.get(ValueLayout.JAVA_BYTE, 2));
    }
}
