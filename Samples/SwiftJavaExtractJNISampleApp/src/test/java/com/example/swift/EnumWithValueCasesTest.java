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
import org.swift.swiftkit.core.ConfinedSwiftMemorySession;
import org.swift.swiftkit.core.SwiftArena;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

public class EnumWithValueCasesTest {
    @Test
    void fn() {
        try (var arena = SwiftArena.ofConfined()) {
            EnumWithValueCases e = EnumWithValueCases.firstCase(48, arena);
            EnumWithValueCases.FirstCase c = (EnumWithValueCases.FirstCase) e.getCase();
            assertNotNull(c);
        }
    }
}