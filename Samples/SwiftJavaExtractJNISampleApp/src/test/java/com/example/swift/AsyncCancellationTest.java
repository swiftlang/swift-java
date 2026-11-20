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
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.swift.swiftkit.core.SwiftArena;

import java.util.concurrent.CancellationException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.BooleanSupplier;

import static org.junit.jupiter.api.Assertions.*;

public class AsyncCancellationTest {
    @ParameterizedTest
    @ValueSource(strings = {"scalar", "optional"})
    void cancelsSwiftTask(String resultType) throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            var probe = AsyncCancellationProbe.init(arena);
            Future<?> future = switch (resultType) {
                case "scalar" -> probe.waitForCancellation();
                case "optional" -> probe.waitForOptionalCancellation();
                default -> throw new IllegalArgumentException();
            };
            assertTrue(future.cancel(false));
            awaitCondition(probe::wasCancelled, "Swift task did not observe cancellation");
        }
    }


    @Test
    void closingArenaReleasesResult() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            var probe = AsyncCancellationProbe.init(arena);
            try (var resultArena = SwiftArena.ofConfined()) {
                var result = get(probe.makeOwnedResult(resultArena));
                assertFalse(result.$cleanup().isDestroyed());
                assertEquals(0, probe.destroyedResults());
            }
            awaitCondition(() -> probe.destroyedResults() == 1, "Swift result was not destroyed");
        }
    }

    @Test
    void closingArenaReleasesTupleResults() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            var probe = AsyncCancellationProbe.init(arena);
            try (var resultArena = SwiftArena.ofConfined()) {
                assertNotNull(get(probe.makeOwnedTuple(resultArena)));
                assertEquals(0, probe.destroyedResults());
            }
            awaitCondition(() -> probe.destroyedResults() == 2, "Swift tuple elements were not destroyed");
        }
    }

    @ParameterizedTest
    @ValueSource(ints = {1, 2})
    void cancelBeforeArenaTakesOwnership(int expectedDestroyed) throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            var probe = AsyncCancellationProbe.init(arena);
            try (var resultArena = SwiftArena.ofConfined()) {
                Future<?> future = switch (expectedDestroyed) {
                    case 1 -> probe.returnOwnedResultAfterCancellation(resultArena);
                    case 2 -> probe.returnOwnedResultsAfterCancellation(resultArena);
                    default -> throw new IllegalArgumentException();
                };
                assertTrue(future.cancel(false));
                awaitCondition(probe::wasCancelled, "Swift task did not observe cancellation");
            }
            awaitCondition(() -> probe.destroyedResults() == expectedDestroyed, "Late Swift results were not destroyed");
        }
    }

    @Test
    void cancelAfterArenaTakesOwnership() throws Exception {
        try (var probeArena = SwiftArena.ofConfined()) {
            var probe = AsyncCancellationProbe.init(probeArena);
            try (var resultArena = SwiftArena.ofConfined()) {
                var futureToCancel = new AtomicReference<Future<?>>();
                Future<AsyncOwnedResult> future = probe.returnOwnedResultWhenAllowed(instance -> {
                    resultArena.register(instance);
                    futureToCancel.get().cancel(false);
                });
                futureToCancel.set(future);

                awaitCondition(probe::isWaitingToReturn, "Swift task did not pause before returning");
                probe.allowReturn();

                assertThrows(CancellationException.class, () -> get(future));
                assertEquals(0, probe.destroyedResults());
            }
            awaitCondition(() -> probe.destroyedResults() == 1, "Swift result was not destroyed");
        }
    }

    @Test
    void releaseElementsIfArenaIsAlreadyClosed() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            var probe = AsyncCancellationProbe.init(arena);
            var closedArena = SwiftArena.ofConfined();
            closedArena.close();

            var failure = assertThrows(ExecutionException.class, () -> get(probe.makeOwnedResults(closedArena)));
            assertEquals("SwiftArena is already closed!", failure.getCause().getMessage());
            awaitCondition(() -> probe.destroyedResults() == 2, "Swift array elements were not destroyed");
        }
    }

    private static <T> T get(Future<T> future) throws InterruptedException, ExecutionException, TimeoutException {
        return future.get(5, TimeUnit.SECONDS);
    }

    private static void awaitCondition(BooleanSupplier condition, String message) throws InterruptedException {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (!condition.getAsBoolean()) {
            assertTrue(System.nanoTime() - deadline < 0, message);
            Thread.sleep(5);
        }
    }
}
