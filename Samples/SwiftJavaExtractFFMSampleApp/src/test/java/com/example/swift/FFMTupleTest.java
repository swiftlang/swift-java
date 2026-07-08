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
import org.swift.swiftkit.core.tuple.Tuple2;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Runtime coverage for Swift tuples exported via jextract FFM (see {@code Tuples.swift} in the sample library).
 */
public class FFMTupleTest {

    static {
        System.loadLibrary(MySwiftLibrary.LIB_NAME);
    }

    @Test
    void returnIntPair_roundTrip() {
        // snippet.tupleUsageJava
        Tuple2<Integer, Long> result = MySwiftLibrary.returnIntPair();
        assertEquals(42, result.$0);
        assertEquals(43L, result.$1);
        // snippet.end
    }

    @Test
    void sumIntPair_acceptsTupleFromJava() {
        long sum = MySwiftLibrary.sumIntPair(new Tuple2<>(5, 7L));
        assertEquals(12L, sum);
    }

    @Test
    void labeledTuple_preservesElementOrder() {
        Tuple2<Integer, Integer> result = MySwiftLibrary.labeledTuple();
        assertEquals(10, result.$0);
        assertEquals(20, result.$1);
    }
}
