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

import java.util.OptionalLong;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;

import static org.junit.jupiter.api.Assertions.*;

public class ArraysTest {
    @Test
    void booleanArray() {
        boolean[] input = new boolean[] { true, false, false, true };
        assertArrayEquals(input, MySwiftLibrary.booleanArray(input));
    }

    @Test
    void byteArray() {
        byte[] input = new byte[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.byteArray(input));
    }

    @Test
    void byteArray_empty() {
        byte[] input = new byte[] {};
        assertArrayEquals(input, MySwiftLibrary.byteArray(input));
    }

    @Test
    void byteArray_null() {
        assertThrows(NullPointerException.class, () -> MySwiftLibrary.byteArray(null));
    }

    @Test
    void byteArrayExplicit() {
        byte[] input = new byte[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.byteArrayExplicit(input));
    }

    @Test
    void charArray() {
        char[] input = new char[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.charArray(input));
    }

    @Test
    void shortArray() {
        short[] input = new short[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.shortArray(input));
    }

    @Test
    void intArray() {
        int[] input = new int[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.intArray(input));
    }

    @Test
    void longArray() {
        long[] input = new long[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.longArray(input));
    }

    @Test
    void stringArray() {
        String[] input = new String[] { "hey", "there", "my", "friend" };
        assertArrayEquals(input, MySwiftLibrary.stringArray(input));
    }

    @Test
    void floatArray() {
        float[] input = new float[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.floatArray(input));
    }

    @Test
    void doubleArray() {
        double[] input = new double[] { 10, 20, 30, 40 };
        assertArrayEquals(input, MySwiftLibrary.doubleArray(input));
    }

    @Test
    void objectArray() {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftClass[] input = new MySwiftClass[]{MySwiftClass.init(arena), MySwiftClass.init(arena), MySwiftClass.init(arena) };
            assertEquals(3, MySwiftLibrary.objectArray(input, arena).length);
        }
    }

    @Test
    void nestedByteArray() {
        byte[][] input = new byte[][] {
            { 1, 2, 3 },
            { 4, 5 },
            { 6 }
        };
        byte[][] result = MySwiftLibrary.nestedByteArray(input);
        assertEquals(input.length, result.length);
        assertArrayEquals(input[0], result[0]);
        assertArrayEquals(input[1], result[1]);
        assertArrayEquals(input[2], result[2]);
    }

    @Test
    void nestedByteArray_empty() {
        byte[][] input = new byte[][] {};
        byte[][] result = MySwiftLibrary.nestedByteArray(input);
        assertEquals(0, result.length);
    }

    @Test
    void nestedByteArray_emptyInner() {
        byte[][] input = new byte[][] { {}, { 1 }, {} };
        byte[][] result = MySwiftLibrary.nestedByteArray(input);
        assertEquals(3, result.length);
        assertArrayEquals(new byte[] {}, result[0]);
        assertArrayEquals(new byte[] { 1 }, result[1]);
        assertArrayEquals(new byte[] {}, result[2]);
    }

    @Test
    void nestedLongArray() {
        long[][] input = new long[][] {
            { 100, 200, 300 },
            { 400, 500 }
        };
        long[][] result = MySwiftLibrary.nestedLongArray(input);
        assertEquals(input.length, result.length);
        assertArrayEquals(input[0], result[0]);
        assertArrayEquals(input[1], result[1]);
    }

    @Test
    void nestedStringArray() {
        String[][] input = new String[][] {
            { "hello", "world" },
            { "foo", "bar", "baz" }
        };
        String[][] result = MySwiftLibrary.nestedStringArray(input);
        assertEquals(input.length, result.length);
        assertArrayEquals(input[0], result[0]);
        assertArrayEquals(input[1], result[1]);
    }

    @Test
    void nestedStringArray_empty() {
        String[][] input = new String[][] {};
        String[][] result = MySwiftLibrary.nestedStringArray(input);
        assertEquals(0, result.length);
    }

    @Test
    void nestedStringArray_emptyInner() {
        String[][] input = new String[][] { {}, { "a" }, {} };
        String[][] result = MySwiftLibrary.nestedStringArray(input);
        assertEquals(3, result.length);
        assertArrayEquals(new String[] {}, result[0]);
        assertArrayEquals(new String[] { "a" }, result[1]);
        assertArrayEquals(new String[] {}, result[2]);
    }
}
