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

import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.util.concurrent.Callable;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Supplier;

public abstract class SwiftValue implements SwiftInstance {
    /// Pointer to the "self".
    private final MemorySegment selfMemorySegment;

    public final MemorySegment $memorySegment() {
        return this.selfMemorySegment;
    }

    // TODO: make this a flagset integer and/or use a field updater
    /** Used to track additional state of the underlying object, e.g. if it was explicitly destroyed. */
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    @Override
    public final AtomicBoolean $statusDestroyedFlag() {
        return this.$state$destroyed;
    }

    public final void $ensureAlive() {
        if (this.$state$destroyed.get()) {
            throw new IllegalStateException("Attempted to call method on already destroyed instance of " + getClass().getSimpleName() + "!");
        }
    }

    /**
     * @param segment the memory segment.
     * @param arena the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
     */
    public SwiftValue(MemorySegment segment, SwiftArena arena) {
        this.selfMemorySegment = segment;
        arena.register(this);
    }

    /**
     * Convenience constructor subclasses can call like:
     * {@snippet :
     * super(() -> { ...; return segment; }, swiftArena$)
     * }
     *
     * @param segmentSupplier Should return the memory segment of the value
     * @param arena the arena where the supplied segment belongs to. When the arena goes out of scope, this value is destroyed.
     */
    protected SwiftValue(Supplier<MemorySegment> segmentSupplier, SwiftArena arena) {
        this(segmentSupplier.get(), arena);
    }

    public abstract SwiftAnyType $swiftType();
}
