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

import java.util.Optional;
import java.util.OptionalLong;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.SwiftArena;
import org.swift.swiftkit.core.tuple.Tuple2;

import static org.junit.jupiter.api.Assertions.*;

public class GenericTypeTest {
    @Test
    void genericTypeValueRoundtrip() {
        try (var arena = SwiftArena.ofConfined()) {
            MyID<String> stringId = MyIDs.makeStringID("Java", arena);
            assertEquals("Java", stringId.getDescription());
            assertEquals("Java", MyIDs.takeStringValue(stringId));

            MyID<Long> intId = MyIDs.makeIntID(42, arena);
            assertEquals("42", intId.getDescription());
            assertEquals(42, MyIDs.takeIntValue(intId));

            Tuple2<MyID<String>, MyID<Long>> ids = MyIDs.makeIDs("Java", 42, arena);
            assertEquals("Java", ids.$0.getDescription());
            assertEquals("42", ids.$1.getDescription());
            assertEquals("Java", MyIDs.takeValuesFromTuple(ids).$0);
            assertEquals(42, MyIDs.takeValuesFromTuple(ids).$1);

            Optional<MyID<Double>> doubleIdOptional = MyIDs.makeDoubleIDOptional(42.195, arena);
            assertTrue(doubleIdOptional.isPresent());
            assertEquals(42.195, MyIDs.takeDoubleValueOptional(doubleIdOptional).getAsDouble());
            assertEquals(42.195, MyIDs.takeDoubleValue(doubleIdOptional.get())); // ensure wrapped value is alive

            MyID<Optional<String>> optionalStringId = MyIDs.makeOptionalStringID(Optional.of("Java"), arena);
            assertEquals("Optional(\"Java\")", optionalStringId.getDescription());
            assertEquals("Java", MyIDs.takeOptionalStringValue(optionalStringId).get());
        }
    }

    @Test
    void genericTypeProperty() {
        try (var arena = SwiftArena.ofConfined()) {
            MyID<Long> intId = MyIDs.makeIntID(42, arena);
            MyEntity entity = MyEntity.init(intId, "name", arena);
            assertEquals("42", entity.getId(arena).getDescription());
        }
    }

    @Test
    void genericEnum() {
        try (var arena = SwiftArena.ofConfined()) {
            GenericEnum<Long> value = MySwiftLibrary.makeIntGenericEnum(arena);
            switch (value.getCase()) {
                case GenericEnum.Case.Foo _ -> assertTrue(value.getAsFoo().isPresent());
                case GenericEnum.Case.Bar _ -> assertTrue(value.getAsBar().isPresent());
            }
        }
    }
}
