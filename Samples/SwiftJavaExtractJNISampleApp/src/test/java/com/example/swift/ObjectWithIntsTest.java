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

public class ObjectWithIntsTest {
    @Test
    void init() {
        try (var arena = SwiftArena.ofConfined()) {
            ObjectWithInts obj = ObjectWithInts.init(-45, 45, arena);
            assertEquals(-45, obj.getNormalInt());
            assertEquals(45, obj.getUnsignedInt());
        }
    }

    @Test
    void callMe() {
        try (var arena = SwiftArena.ofConfined()) {
            ObjectWithInts obj = ObjectWithInts.init(-45, 45, arena);
            assertEquals(66, obj.callMe(66));
        }
    }
}