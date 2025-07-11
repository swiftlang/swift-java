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

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftClassTest {
    @Test
    void init_noParameters() {
        try (var arena = new ConfinedSwiftMemorySession(Thread.currentThread())) {
            MySwiftClass c = MySwiftClass.init(arena);
            assertNotNull(c);
        }
    }

    @Test
    void init_withParameters() {
        try (var arena = new ConfinedSwiftMemorySession(Thread.currentThread())) {
            MySwiftClass c = MySwiftClass.init(1337, 42, arena);
            assertNotNull(c);
        }
    }
}