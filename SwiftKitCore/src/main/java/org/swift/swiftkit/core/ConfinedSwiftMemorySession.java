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

package org.swift.swiftkit.core;

import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;

public class ConfinedSwiftMemorySession implements ClosableSwiftArena {
    private final ConfinedResourceList resources = new ConfinedResourceList();
    private boolean closed;

    private void checkValid() {
        if (closed) {
            throw new RuntimeException("SwiftArena is already closed!");
        }
    }

    @Override
    public void close() {
        synchronized (resources) {
            checkValid();
            closed = true;
        }
        resources.runCleanup();
    }

    @Override
    public void register(SwiftInstance instance) {
        SwiftInstanceCleanup cleanup = instance.$cleanup();
        synchronized (resources) {
            checkValid();
            resources.add(cleanup);
        }
    }

    static final class ConfinedResourceList implements SwiftResourceList {
        final Queue<SwiftInstanceCleanup> resourceCleanups = new ConcurrentLinkedQueue<>();

        void add(SwiftInstanceCleanup cleanup) {
            resourceCleanups.add(cleanup);
        }

        @Override
        public void runCleanup() {
            for (SwiftInstanceCleanup cleanup : resourceCleanups) {
                cleanup.run();
            }
            resourceCleanups.clear();
        }
    }
}
