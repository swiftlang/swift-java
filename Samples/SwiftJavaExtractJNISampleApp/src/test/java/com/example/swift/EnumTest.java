//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
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

public class EnumTest {
    @Test
    void enumWithValueCases() {
        try (var arena = SwiftArena.ofConfined()) {
            EnumWithValueCases e = EnumWithValueCases.firstCase(48, arena);
            EnumWithValueCases.Case.FirstCase c = (EnumWithValueCases.Case.FirstCase) e.getCase();
            assertNotNull(c);
        }
    }

    @Test
    void enumWithBacktick() {
        try (var arena = SwiftArena.ofConfined()) {
            EnumWithBacktick e = EnumWithBacktick.default_(arena);
            assertTrue(e.getAsDefault().isPresent());
        }
    }

    @Test
    void enumWithCaseNameValue() {
        try (var arena = SwiftArena.ofConfined()) {
            var success = EnumWithCaseNameValue.Success.init("ok", arena);
            EnumWithCaseNameValue e = EnumWithCaseNameValue.success(success, arena);
         
            switch (e.getCase(arena)) {
            case EnumWithCaseNameValue.Case.Success(var s):
                assertEquals("ok", s.getMessage());
            }
        }
    }
}
