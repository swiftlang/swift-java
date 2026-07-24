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
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class OperatorsTest {
    @Test
    void plus() {
        try (var arena = SwiftArena.ofConfined()) {
            var left = OperatorScore.init(40, arena);
            var right = OperatorScore.init(2, arena);

            var result = OperatorScore.plus(left, right, arena);

            assertEquals(42, result.getValue());
        }
    }

    @Test
    void randomOperator() {
        try (var arena = SwiftArena.ofConfined()) {
            var left = OperatorScore.init(40, arena);
            var right = OperatorScore.init(2, arena);

            var result = OperatorScore.plusMinusIsEqualTimes(left, right);

            assertEquals("Called +-==* in Java successfully with left: 40 and right: 2", result);
        }
    }
}
