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

package org.swift.swiftkit.ffm;

import org.junit.jupiter.api.Test;

import java.lang.foreign.MemorySegment;

import static org.junit.jupiter.api.Assertions.*;

public class FFMSwiftInstanceInvalidationTest {

    @Test
    public void memoryAccessors_throwAfterArenaClose() {
        FakeSwiftInstance instance;
        MemorySegment segment = MemorySegment.ofAddress(0x1000L);
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            instance = new FakeSwiftInstance(arena, segment);
            assertEquals(0x1000L, instance.$memoryAddress());
            assertEquals(segment, instance.$memorySegment());
            assertFalse(instance.$cleanup().isDestroyed());
        }

        assertTrue(instance.$cleanup().isDestroyed());
        IllegalStateException segmentEx = assertThrows(IllegalStateException.class, instance::$memorySegment);
        IllegalStateException addressEx = assertThrows(IllegalStateException.class, instance::$memoryAddress);
        assertTrue(segmentEx.getMessage().contains("already destroyed"));
        assertTrue(addressEx.getMessage().contains("already destroyed"));
        assertThrows(IllegalStateException.class, instance::$ensureAlive);
    }

    private static class FakeSwiftInstance extends FFMSwiftInstance {
        FakeSwiftInstance(AllocatingSwiftArena arena, MemorySegment segment) {
            super(segment, arena);
        }

        @Override
        public SwiftAnyType $swiftType() {
            // Null type skips the native destroy path, so this test can run without Swift libs.
            return null;
        }
    }
}
