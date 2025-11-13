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

public class NestedTypesTest {
    @Test
    void testClassesAndStructs() {
        try (var arena = SwiftArena.ofConfined()) {
            var a = A.init(arena);
            var b = A.B.init(arena);
            var c = A.B.C.init(arena);
            var bb = A.BB.init(arena);
            var abbc = A.BB.C.init(arena);

            a.f(a, b, c, bb, abbc);
            c.g(a, b, abbc);
        }
    }

    /*@Test
    void testStructInEnum() {
        try (var arena = SwiftArena.ofConfined()) {
            var obj = NestedEnum.one(NestedEnum.OneStruct.init(arena), arena);
            var one = obj.getAsOne(arena);
            assertTrue(one.isPresent());
        }
    }*/
}