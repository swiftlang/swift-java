//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.swiftkit;

import org.junit.jupiter.api.Test;

import java.lang.foreign.GroupLayout;
import java.lang.foreign.MemorySegment;
import java.lang.ref.Cleaner;
import java.util.concurrent.CountDownLatch;

public class AutoArenaTest {


    @Test
    @SuppressWarnings("removal") // System.runFinalization() will be removed
    public void cleaner_releases_native_resource() {
        SwiftHeapObject object = new FakeSwiftHeapObject();

        // Latch waiting for the cleanup of the object
        var cleanupLatch = new CountDownLatch(1);

        // we're retaining the `object`, register it with the arena:
        AutoSwiftMemorySession arena = (AutoSwiftMemorySession) SwiftArena.ofAuto();
        arena.register(object, new SwiftHeapObjectCleanup(object.$memorySegment(), object.$swiftType()) {
            @Override
            public void run() throws UnexpectedRetainCountException {
                cleanupLatch.countDown();
            }
        });

        // Release the object and hope it gets GC-ed soon

        //noinspection UnusedAssignment
        object = null;

        var i = 1_000;
        while (cleanupLatch.getCount() != 0) {
            System.runFinalization();
            System.gc();

            if (i-- < 1) {
                throw new RuntimeException("Reference was not cleaned up! Did Cleaner not pick up the release?");
            }
        }

    }

    private static class FakeSwiftHeapObject implements SwiftHeapObject {
        public FakeSwiftHeapObject() {
        }

        @Override
        public MemorySegment $memorySegment() {
            return MemorySegment.NULL;
        }

        @Override
        public GroupLayout $layout() {
            return null;
        }

        @Override
        public SwiftAnyType $swiftType() {
            return null;
        }
    }
}
