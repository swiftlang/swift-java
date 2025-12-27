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

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

public class DateTest {
    @Test
    void date() {
        assertEquals(Instant.ofEpochSecond(1000), MySwiftLibrary.dateFromSeconds(1000.0));
        assertEquals(Instant.ofEpochSecond(1000, 500_000_000), MySwiftLibrary.dateFromSeconds(1000.50));
        assertTrue(MySwiftLibrary.compareDates(Instant.ofEpochSecond(5000), Instant.ofEpochSecond(5000)));
        assertFalse(MySwiftLibrary.compareDates(Instant.ofEpochSecond(4999, 500_000_000), Instant.ofEpochSecond(5000)));
        assertTrue(MySwiftLibrary.compareDates(MySwiftLibrary.dateFromSeconds(1000.5), Instant.ofEpochSecond(1000, 500_000_000)));

        var date = MySwiftLibrary.dateFromSeconds(50000.5);
        assertEquals(50_000, date.getEpochSecond());
        assertEquals(500_000_000, date.getNano());
    }
}