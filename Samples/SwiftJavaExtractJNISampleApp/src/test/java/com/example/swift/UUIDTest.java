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
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

public class UUIDTest {
    @Test
    void echoUUID() {
        var uuid = UUID.randomUUID();
        assertEquals(uuid, MySwiftLibrary.echoUUID(uuid));
    }

    @Test
    void makeUUID() {
        var uuid = MySwiftLibrary.makeUUID();
        assertEquals(4, uuid.version());
    }
}