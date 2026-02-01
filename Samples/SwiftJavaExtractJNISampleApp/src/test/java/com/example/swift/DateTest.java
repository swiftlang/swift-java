//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
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

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static org.junit.jupiter.api.Assertions.*;

public class DateTest {
    @Test
    void date_functions() {
        try (var arena = SwiftArena.ofConfined()) {
            var date = MySwiftLibrary.dateFromSeconds(1000.50, arena);
            assertEquals(1000.5, date.getTimeIntervalSince1970());

            var date2 = Date.init(1000.5, arena);
            assertTrue(MySwiftLibrary.compareDates(date, date2));

            var date3 = Date.init(1000.49, arena);
            assertFalse(MySwiftLibrary.compareDates(date, date3));
        }
    }

    @Test
    void date_helpers() {
        try (var arena = SwiftArena.ofConfined()) {
            var nowInstant = Instant.now();
            var date = Date.fromInstant(nowInstant, arena);
            var converted = date.toInstant();

            long diffNanos = Math.abs(ChronoUnit.NANOS.between(nowInstant, converted));
            System.out.println(diffNanos);
            assertTrue(diffNanos < 1000,
                    "Precision loss should be contained to sub-microseconds. Actual drift: " + diffNanos + "ns");
            assertEquals(nowInstant.getEpochSecond(), converted.getEpochSecond());
        }
    }

    @Test
    void date_timeIntervalSince1970() {
        try (var arena = SwiftArena.ofConfined()) {
            var date = Date.init(1000, arena);
            assertEquals(1000, date.getTimeIntervalSince1970());
        }
    }
}