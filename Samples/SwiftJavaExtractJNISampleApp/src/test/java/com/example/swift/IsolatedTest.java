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

import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.*;

public class IsolatedTest {
    @Test
    void increment() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            Counter counter = Counter.init(arena);

            Future<Long> afterFirstIncrement = MySwiftLibrary.increment(counter, 3);
            assertEquals(3, afterFirstIncrement.get());

            Future<Long> afterSecondIncrement = MySwiftLibrary.increment(counter, 4);
            assertEquals(7, afterSecondIncrement.get());

            Future<Long> reset = MySwiftLibrary.reset(counter);
            assertEquals(7, reset.get());

            Future<Long> resetAgain = MySwiftLibrary.reset(counter);
            assertEquals(0, resetAgain.get());
        }
    }

    @Test
    void incrementThrows() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            Counter counter = Counter.init(arena);
            Future<Long> future = MySwiftLibrary.incrementThrows(counter);

            ExecutionException ex = assertThrows(ExecutionException.class, future::get);

            Throwable cause = ex.getCause();
            assertNotNull(cause);
            assertEquals(Exception.class, cause.getClass());
            assertEquals("swiftError", cause.getMessage());
        }
    }

    @Test
    void actorIsolatedMethodReturnsFuture() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            Counter counter = Counter.init(arena);

            Future<Long> afterFirst = counter.incrementIsolated(3);
            assertEquals(3, afterFirst.get());

            Future<Long> afterSecond = counter.incrementIsolated(4);
            assertEquals(7, afterSecond.get());
        }
    }

    @Test
    void actorIsolatedMethodInExtensionReturnsFuture() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            Counter counter = Counter.init(arena);
            counter.incrementIsolated(5).get();

            Future<Long> current = counter.currentValue();
            assertEquals(5, current.get());
        }
    }

    @Test
    void nonisolatedMethodStaysSynchronous() {
        try (var arena = SwiftArena.ofConfined()) {
            Counter counter = Counter.init(arena);

            String label = counter.label();
            assertEquals("Counter", label);
        }
    }
}
