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
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class OperatorsTest {
    @Test
    void binaryOperators() {
        // snippet.operatorsUsageJava
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var left = OperatorScore.init(40, arena);
            var right = OperatorScore.init(2, arena);

            // left + right
            var sum = OperatorScore.plus(left, right, arena);
            assertEquals(42, sum.getValue());

            // left +-==* right
            var result = OperatorScore.plusMinusIsEqualTimes(left, right);
            assertEquals("Called +-==* in Java successfully with left: 40 and right: 2", result);

            // 2 * left, declared at file scope
            var doubled = MySwiftLibrary.times(2, left, arena);
            assertEquals(80, doubled.getValue());
        }
        // snippet.end
    }

    @Test
    void binaryAndPrefixMinus() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var left = OperatorScore.init(40, arena);
            var right = OperatorScore.init(2, arena);

            assertEquals(38, OperatorScore.minus(left, right, arena).getValue());
            assertEquals(-40, OperatorScore.minus(left, arena).getValue());
        }
    }

    @Test
    void prefixAndPostfixOperators() {
        // snippet.prefixPostfixOperatorsUsageJava
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var score = OperatorScore.init(42, arena);

            // -score
            var negated = OperatorScore.minus(score, arena);
            assertEquals(-42, negated.getValue());

            // score++
            var incremented = OperatorScore.plusPlus(score, arena);
            assertEquals(43, incremented.getValue());
        }
        // snippet.end
    }
}
