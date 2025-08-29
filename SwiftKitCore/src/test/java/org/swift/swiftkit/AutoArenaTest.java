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

package org.swift.swiftkit;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.JNISwiftInstance;
import org.swift.swiftkit.core.SwiftArena;

import java.util.concurrent.atomic.AtomicBoolean;

public class AutoArenaTest {

    @Test
    @SuppressWarnings("removal") // System.runFinalization() will be removed
    public void cleaner_releases_native_resource() {
        SwiftArena arena = SwiftArena.ofAuto();

        // This object is registered to the arena.
        var object = new FakeSwiftInstance(arena);
        var statusDestroyedFlag = object.$statusDestroyedFlag();

        // Release the object and hope it gets GC-ed soon

        // noinspection UnusedAssignment
        object = null;

        var i = 1_000;
        while (!statusDestroyedFlag.get()) {
            System.runFinalization();
            System.gc();

            if (i-- < 1) {
                throw new RuntimeException("Reference was not cleaned up! Did Cleaner not pick up the release?");
            }
        }
    }

    private static class FakeSwiftInstance implements JNISwiftInstance {
        AtomicBoolean $state$destroyed = new AtomicBoolean(false);

        public FakeSwiftInstance(SwiftArena arena) {
            arena.register(this);
        }

        public Runnable $createDestroyFunction() {
            return () -> {};
        }

        @Override
        public long $typeMetadataAddress() {
            return 0;
        }

        @Override
        public long $memoryAddress() {
            return 0;
        }

        @Override
        public AtomicBoolean $statusDestroyedFlag() {
            return $state$destroyed;
        }
    }
}
