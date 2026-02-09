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

import static org.junit.jupiter.api.Assertions.*;

public class DataTest {
    @Test
    void data_echo() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] bytes = new byte[] { 1, 2, 3, 4 };
            var data = Data.fromByteArray(bytes, arena);

            var echoed = MySwiftLibrary.echoData(data, arena);
            assertEquals(4, echoed.getCount());
        }
    }

    @Test
    void data_make() {
        try (var arena = SwiftArena.ofConfined()) {
            var data = MySwiftLibrary.makeData(arena);
            assertEquals(4, data.getCount());
        }
    }

    @Test
    void data_getCount() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] bytes = new byte[] { 1, 2, 3, 4, 5 };
            var data = Data.fromByteArray(bytes, arena);
            assertEquals(5, MySwiftLibrary.getDataCount(data));
        }
    }

    @Test
    void data_compare() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] bytes1 = new byte[] { 1, 2, 3 };
            byte[] bytes2 = new byte[] { 1, 2, 3 };
            byte[] bytes3 = new byte[] { 1, 2, 4 };

            var data1 = Data.fromByteArray(bytes1, arena);
            var data2 = Data.fromByteArray(bytes2, arena);
            var data3 = Data.fromByteArray(bytes3, arena);

            assertTrue(MySwiftLibrary.compareData(data1, data2));
            assertFalse(MySwiftLibrary.compareData(data1, data3));
        }
    }

    @Test
    void data_toByteArray() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] original = new byte[] { 10, 20, 30, 40 };
            var data = Data.fromByteArray(original, arena);

            byte[] result = data.toByteArray();

            assertEquals(original.length, result.length);
            assertArrayEquals(original, result);
        }
    }

    @Test
    void data_toByteArrayDirect() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] original = new byte[] { 10, 20, 30, 40 };
            var data = Data.fromByteArray(original, arena);

            byte[] result = data.toByteArrayDirect();

            assertEquals(original.length, result.length);
            assertArrayEquals(original, result);
        }
    }

    @Test
    void data_toByteArray_empty() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] original = new byte[] {};
            var data = Data.fromByteArray(original, arena);

            byte[] result = data.toByteArray();

            assertArrayEquals(original, result);
            assertEquals(0, result.length);
        }
    }

    @Test
    void data_roundTrip() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] original = new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 };
            var data = Data.fromByteArray(original, arena);
            var echoed = MySwiftLibrary.echoData(data, arena);

            byte[] result = echoed.toByteArray();

            assertArrayEquals(original, result);
        }
    }

    @Test
    void data_toByteArrayDirect_roundTrip() {
        try (var arena = SwiftArena.ofConfined()) {
            byte[] original = new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 };
            var data = Data.fromByteArray(original, arena);
            var echoed = MySwiftLibrary.echoData(data, arena);

            byte[] result = echoed.toByteArrayDirect();

            assertArrayEquals(original, result);
        }
    }
}
