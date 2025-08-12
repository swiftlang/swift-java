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

public class AlignmentEnumTest {
    @Test
    void rawValue() {
        try (var arena = SwiftArena.ofConfined()) {
            Optional<Alignment> invalid = Alignment.init("invalid", arena);
            assertFalse(invalid.isPresent());

            Optional<Alignment> horizontal = Alignment.init("horizontal", arena);
            assertTrue(horizontal.isPresent());
            assertEquals("horizontal", horizontal.get().getRawValue());

            Optional<Alignment> vertical = Alignment.init("vertical", arena);
            assertTrue(vertical.isPresent());
            assertEquals("vertical", vertical.get().getRawValue());
        }
    }
}