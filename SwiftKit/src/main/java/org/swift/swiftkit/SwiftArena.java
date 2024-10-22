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

import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * A Swift arena manages Swift allocated memory for classes, structs, enums etc.
 * When an arena is closed, it will destroy all managed swift objects in a way appropriate to their type.
 * <p>
 * A confined arena has an associated owner thread that confines some operations to
 * associated owner thread such as {@link #close()}.
 */
public interface SwiftArena extends AutoCloseable {

    static SwiftArena ofConfined() {
        return new ConfinedSwiftMemorySession(Thread.currentThread());
    }

    /**
     * Register a Swift reference counted heap object with this arena (such as a {@code class} or {@code actor}).
     * Its memory should be considered managed by this arena, and be destroyed when the arena is closed.
     */
    void register(SwiftHeapObject object);

    /**
     * Register a struct, enum or other non-reference counted Swift object.
     * Its memory should be considered managed by this arena, and be destroyed when the arena is closed.
     */
    void register(SwiftValue value);

    /**
     * Close the arena and make sure all objects it managed are released.
     * Throws if unable to verify all resources have been release (e.g. over retained Swift classes)
     */
    void close();

}

final class ConfinedSwiftMemorySession implements SwiftArena {

//    final Arena underlying;
    final Thread owner;
    final SwiftResourceList resources;

    final int CLOSED = 0;
    final int ACTIVE = 1;
    final AtomicInteger state;

    public ConfinedSwiftMemorySession(Thread owner) {
        this.owner = owner;
        resources = new ConfinedResourceList();
        state = new AtomicInteger(ACTIVE);
    }

    public void checkValid() throws RuntimeException {
        if (this.owner != null && this.owner != Thread.currentThread()) {
            throw new WrongThreadException("ConfinedSwift arena is confined to %s but was closed from %s!".formatted(this.owner, Thread.currentThread()));
        } else if (this.state.get() < ACTIVE) {
            throw new RuntimeException("Arena is already closed!");
        }
    }

    @Override
    public void register(SwiftHeapObject object) {
        this.resources.add(new SwiftHeapObjectCleanup(object));
    }

    @Override
    public void register(SwiftValue value) {
        this.resources.add(new SwiftValueCleanup(value.$memorySegment()));
    }

    @Override
    public void close() {
        checkValid();

        // Cleanup all resources
        if (this.state.compareAndExchange(ACTIVE, CLOSED) == ACTIVE) {
            this.resources.cleanup();
        } // else, was already closed; do nothing
    }

    /**
     * Represents a list of resources that need a cleanup, e.g. allocated classes/structs.
     */
    static abstract class SwiftResourceList implements Runnable {
        // TODO: Could use intrusive linked list to avoid one indirection here
        final List<SwiftInstanceCleanup> resourceCleanups = new LinkedList<>();

        abstract void add(SwiftInstanceCleanup cleanup);

        public abstract void cleanup();

        public final void run() {
            cleanup(); // cleaner interop
        }
    }

    static final class ConfinedResourceList extends SwiftResourceList {
        @Override
        void add(SwiftInstanceCleanup cleanup) {
            resourceCleanups.add(cleanup);
        }

        @Override
        public void cleanup() {
            for (SwiftInstanceCleanup cleanup : resourceCleanups) {
                cleanup.run();
            }
        }
    }


}

final class UnexpectedRetainCountException extends RuntimeException {
    public UnexpectedRetainCountException(Object resource, long retainCount, int expectedRetainCount) {
        super(("Attempting to cleanup managed memory segment %s, but it's retain count was different than [%d] (was %d)! " +
                "This would result in destroying a swift object that is still retained by other code somewhere."
        ).formatted(resource, expectedRetainCount, retainCount));
    }
}
