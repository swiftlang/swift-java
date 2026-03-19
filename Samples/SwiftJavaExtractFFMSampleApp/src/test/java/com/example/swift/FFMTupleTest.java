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
 * Runtime coverage for Swift tuples exported via jextract FFM (see {@code ffmTuple*} in {@link MySwiftLibrary}).
 */
public class FFMTupleTest {

    static {
        System.loadLibrary(MySwiftLibrary.LIB_NAME);
    }

    @Test
    void ffmTupleReturnPair_roundTrip() {
        Tuple2<Long, Long> result = MySwiftLibrary.ffmTupleReturnPair();
        assertEquals(42L, result.$0);
        assertEquals(43L, result.$1);
    }

    @Test
    void ffmTupleSumPair_acceptsTupleFromJava() {
        long sum = MySwiftLibrary.ffmTupleSumPair(new Tuple2<>(5L, 7L));
        assertEquals(12L, sum);
    }

    @Test
    void ffmTupleLabeledPair_preservesElementOrder() {
        Tuple2<Integer, Integer> result = MySwiftLibrary.ffmTupleLabeledPair();
        assertEquals(10, result.$0);
        assertEquals(20, result.$1);
    }
}
