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
    void date_timeIntervalSince1970() {
        try (var arena = SwiftArena.ofConfined()) {
            var date = Date.init(1000, arena);
            assertEquals(1000, date.getTimeIntervalSince1970());
        }
    }
}