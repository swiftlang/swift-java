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

public class GenericTypeTest {
    @Test
    void genericTypeValueRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            var stringId = MySwiftLibrary.makeStringID("Java", arena);
            assertEquals("Java", stringId.getDescription());
            assertEquals("Java", MySwiftLibrary.takeStringValue(stringId));

            var intId = MySwiftLibrary.makeIntID(42, arena);
            assertEquals("42", intId.getDescription());
            assertEquals(42, MySwiftLibrary.takeIntValue(intId));
        }
    }

    @Test
    void genericTypeProperty() {
        try (var arena = SwiftArena.ofConfined()) {
            var intId = MySwiftLibrary.makeIntID(42, arena);
            var entity = MyEntity.init(intId, "name", arena);
            assertEquals("42", entity.getId(arena).getDescription());
        }
    }

    @Test
    void genericEnum() {
        try (var arena = SwiftArena.ofConfined()) {
            var value = MySwiftLibrary.makeIntGenericEnum(arena);
            switch (value.getCase()) {
                case GenericEnum.Foo _ -> assertTrue(value.getAsFoo().isPresent());
                case GenericEnum.Bar _ -> assertTrue(value.getAsBar().isPresent());
            }
        }
    }
}
