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

package org.swift.swiftkit.core;

import org.junit.jupiter.api.Test;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SwiftAsyncResultSinkTest {
    @Test
    void cancellationDuringRegistrationLeavesOnlyRegisteredValueInArena() {
        var firstDestroyed = new AtomicInteger();
        var secondDestroyed = new AtomicInteger();

        try (var arena = SwiftArena.ofConfined()) {
            var futureRef = new AtomicReference<CompletableFuture<OwnedValue[]>>();
            SwiftArena testingArena = value -> {
                arena.register(value);
                // Simulate another thread cancelling the future just after registration.
                assertTrue(futureRef.get().cancel(false));
            };
            var callback = SwiftAsyncResultSink.<long[], OwnedValue[]>create(testingArena, (addresses, resultArena) -> new OwnedValue[] {
                    new OwnedValue(addresses[0], resultArena, firstDestroyed::incrementAndGet),
                    new OwnedValue(addresses[1], resultArena, secondDestroyed::incrementAndGet)
            });
            futureRef.set(callback.future());

            callback.complete(new long[] {1, 2});
            assertTrue(callback.future().isCancelled());
            assertEquals(0, firstDestroyed.get());
            assertEquals(1, secondDestroyed.get());
        }
        assertEquals(1, firstDestroyed.get());
        assertEquals(1, secondDestroyed.get());
    }

    @Test
    void arenaClosedDuringRegistrationLeavesCleanupToCallback() throws Exception {
        var arena = SwiftArena.ofConfined();
        var registering = new CompletableFuture<Void>();
        var closed = new CompletableFuture<Void>();
        var destruction = new AtomicInteger();
        var callback = SwiftAsyncResultSink.<Long, OwnedValue>create(arena, (address, resultArena) ->
                new OwnedValue(address, resultArena, destruction::incrementAndGet) {
                    @Override
                    public SwiftInstanceCleanup $cleanup() {
                        // Signal that arena registration has started.
                        registering.complete(null);
                        // Wait for the test thread to close the arena.
                        closed.orTimeout(5, TimeUnit.SECONDS).join();
                        // Registration will fail when it resumes because the arena is closed.
                        return super.$cleanup();
                    }
                });
        var worker = CompletableFuture.runAsync(() -> callback.complete(1L));
        try {
            registering.get(5, TimeUnit.SECONDS);
            arena.close();
        } finally {
            closed.complete(null);
        }
        worker.get(5, TimeUnit.SECONDS);
        assertTrue(callback.future().isCompletedExceptionally());
        assertEquals(1, destruction.get());
    }

    @Test
    void conversionFailureDestroysAlreadyWrappedValueExactlyOnce() {
        var registered = new AtomicInteger();
        try (var arena = SwiftArena.ofConfined()) {
            var callback = SwiftAsyncResultSink.<long[], OwnedValue[]>create(arena, (addresses, resultArena) -> {
                    new OwnedValue(addresses[0], resultArena, registered::incrementAndGet);
                    throw new IllegalStateException("wrapping result failed");
            });
            callback.complete(new long[] {1, 2, 3});
            assertEquals(1, registered.get());
        }
        assertEquals(1, registered.get());
    }

    @Test
    void cancellationBeforeCallbackStillDestroysEveryOwnedValue() {
        var destruction = new AtomicInteger();
        var registrations = new AtomicInteger();
        SwiftArena arena = (v) -> registrations.incrementAndGet();
        var callback = SwiftAsyncResultSink.<long[], OwnedValue[]>create(arena, (addresses, resultArena) -> new OwnedValue[]{
                new OwnedValue(addresses[0], resultArena, destruction::incrementAndGet),
                new OwnedValue(addresses[1], resultArena, destruction::incrementAndGet)
        });

        assertTrue(callback.future().cancel(false));
        callback.complete(new long[] {1, 2});

        assertEquals(2, destruction.get());
        assertEquals(0, registrations.get());
    }

    private static class OwnedValue implements JNISwiftInstance {
        private final long address;
        private final Runnable destroy;
        private final SwiftInstanceCleanup cleanup;

        OwnedValue(long address, SwiftArena arena, Runnable destroy) {
            this.address = address;
            this.destroy = destroy;
            this.cleanup = $createCleanup();
            arena.register(this);
        }

        @Override
        public long $memoryAddress() {
            return address;
        }

        @Override
        public long $typeMetadataAddress() {
            return 12345;
        }

        @Override
        public SwiftInstanceCleanup $cleanup() {
            return cleanup;
        }

        @Override
        public Runnable $createDestroyFunction() {
            return destroy;
        }
    }
}
