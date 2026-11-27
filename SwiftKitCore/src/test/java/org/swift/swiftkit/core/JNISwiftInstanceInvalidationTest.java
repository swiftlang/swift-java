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

import static org.junit.jupiter.api.Assertions.*;

public class JNISwiftInstanceInvalidationTest {

    @Test
    public void memoryAddress_throwsAfterArenaClose_andPointerIsCleared() {
        FakeSwiftInstance instance;
        try (ClosableSwiftArena arena = SwiftArena.ofConfined()) {
            instance = new FakeSwiftInstance(arena, 0x1000L);
            assertEquals(0x1000L, instance.$memoryAddress());
            assertFalse(instance.$cleanup().isDestroyed());
        }

        assertTrue(instance.$cleanup().isDestroyed());
        assertEquals(0L, instance.pointerValue());
        IllegalStateException ex = assertThrows(IllegalStateException.class, instance::$memoryAddress);
        assertTrue(ex.getMessage().contains("already destroyed"));
        assertThrows(IllegalStateException.class, instance::$ensureAlive);
    }

    private static class FakeSwiftInstance implements JNISwiftInstance {
        private final SwiftInstancePointer selfPointer;
        private final SwiftInstanceCleanup cleanup;

        FakeSwiftInstance(SwiftArena arena, long address) {
            this.selfPointer = new SwiftInstancePointer(address);
            this.cleanup = $createCleanup(this.selfPointer);
            arena.register(this);
        }

        @Override
        public Runnable $createDestroyFunction() {
            return () -> {};
        }

        @Override
        public long $typeMetadataAddress() {
            return 0;
        }

        @Override
        public long $memoryAddress() {
            $ensureAlive();
            return selfPointer.get();
        }

        long pointerValue() {
            return selfPointer.get();
        }

        @Override
        public SwiftInstanceCleanup $cleanup() {
            return cleanup;
        }
    }
}
