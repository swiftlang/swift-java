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
