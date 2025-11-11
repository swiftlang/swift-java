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
}