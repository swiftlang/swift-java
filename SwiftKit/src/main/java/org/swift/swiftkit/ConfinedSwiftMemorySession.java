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

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

final class ConfinedSwiftMemorySession implements ClosableSwiftArena {

    final static int CLOSED = 0;
    final static int ACTIVE = 1;

    final Thread owner;
    final AtomicInteger state;

    final Arena arena;
    final ConfinedResourceList resources;

    public ConfinedSwiftMemorySession(Thread owner) {
        this.owner = owner;
        this.state = new AtomicInteger(ACTIVE);
        this.resources = new ConfinedResourceList();

        this.arena = Arena.ofConfined();
    }

    public void checkValid() throws RuntimeException {
        if (this.owner != null && this.owner != Thread.currentThread()) {
            throw new WrongThreadException("ConfinedSwift arena is confined to %s but was closed from %s!"
                    .formatted(this.owner, Thread.currentThread()));
        } else if (this.state.get() < ACTIVE) {
            throw new RuntimeException("SwiftArena is already closed!");
        }
    }

    @Override
    public void close() {
        checkValid();

        // Cleanup all resources
        if (this.state.compareAndExchange(ACTIVE, CLOSED) == ACTIVE) {
            this.resources.runCleanup();
        } // else, was already closed; do nothing

        this.arena.close();
    }

    @Override
    public void register(SwiftInstance instance) {
        checkValid();

        var statusDestroyedFlag = instance.$statusDestroyedFlag();
        Runnable markAsDestroyed = () -> statusDestroyedFlag.set(true);

        var cleanup = new SwiftInstanceCleanup(
                instance.$memorySegment(),
                instance.$swiftType(),
                markAsDestroyed);
        this.resources.add(cleanup);
    }

    @Override
    public MemorySegment allocate(long byteSize, long byteAlignment) {
        return arena.allocate(byteSize, byteAlignment);
    }

    static final class ConfinedResourceList implements SwiftResourceList {
        // TODO: Could use intrusive linked list to avoid one indirection here
        final List<SwiftInstanceCleanup> resourceCleanups = new LinkedList<>();

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
