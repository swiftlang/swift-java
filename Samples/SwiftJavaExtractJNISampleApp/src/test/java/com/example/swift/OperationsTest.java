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
import org.swift.swiftkit.core.ConfinedSwiftMemorySession;
import org.swift.swiftkit.core.SwiftArena;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

public class OperationsTest {

    @Test
    void operatorAdd() {
        try (var arena = SwiftArena.ofConfined()) {
            MyVector2 a = MyVector2.init(1, 2, arena);
            MyVector2 b = MyVector2.init(3, 4, arena);
            MyVector2 c = MyVector2.plus(a, b, arena);
            assertEquals(c.getX(), 4);
            assertEquals(c.getY(), 6);
        }
    }
}
