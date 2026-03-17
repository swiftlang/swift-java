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

import com.example.swift.MySwiftLibrary;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.tuple.Tuple2;
import org.swift.swiftkit.core.tuple.Tuple3;
import org.swift.swiftkit.core.tuple.Tuple16;

import static org.junit.jupiter.api.Assertions.*;

public class TupleTest {
    @Test
    void returnPair() {
        Tuple2<Long, String> result = MySwiftLibrary.returnPair();
        assertEquals(42L, result.$0);
        assertEquals("hello", result.$1);
    }

    @Test
    void takePair() {
        String result = MySwiftLibrary.takePair(new Tuple2<>(99L, "world"));
        assertEquals("99:world", result);
    }

    @Test
    void labeledTuple() {
        Tuple2<Integer, Integer> result = MySwiftLibrary.labeledTuple();
        assertEquals(10, result.$0);
        assertEquals(20, result.$1);
    }

    @Test
    void echoTriple() {
        Tuple3<Boolean, Double, Long> input = new Tuple3<>(true, 3.14, 100L);
        Tuple3<Boolean, Double, Long> result = MySwiftLibrary.echoTriple(input);
        assertEquals(true, result.$0);
        assertEquals(3.14, result.$1, 0.001);
        assertEquals(100L, result.$2);
    }

    @Test
    void makeBigTuple() {
        Tuple16<Boolean, Byte, Short, Character,
                Integer, Long, Float, Double,
                String, Boolean, Byte, Short,
                Character, Integer, Long, Float> result = MySwiftLibrary.makeBigTuple();
        assertEquals(true, result.$0);
        assertEquals((byte) 1, result.$1);
        assertEquals((short) 2, result.$2);
        assertEquals((char) 3, result.$3);
        assertEquals(4, result.$4);
        assertEquals(5L, result.$5);
        assertEquals(6.0f, result.$6);
        assertEquals(7.0, result.$7);
        assertEquals("eight", result.$8);
        assertEquals(false, result.$9);
        assertEquals((byte) 9, result.$10);
        assertEquals((short) 10, result.$11);
        assertEquals((char) 11, result.$12);
        assertEquals(12, result.$13);
        assertEquals(13L, result.$14);
        assertEquals(14.0f, result.$15);
    }
}
