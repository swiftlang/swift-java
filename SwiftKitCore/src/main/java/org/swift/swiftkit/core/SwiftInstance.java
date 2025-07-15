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

import java.util.concurrent.atomic.AtomicBoolean;

public abstract class SwiftInstance {

    /**
     * Called when the arena has decided the value should be destroyed.
     * <p/>
     * <b>Warning:</b> The cleanup action must not capture {@code this}.
     */
    public abstract SwiftInstanceCleanup createCleanupAction();

    // TODO: make this a flagset integer and/or use a field updater
    /** Used to track additional state of the underlying object, e.g. if it was explicitly destroyed. */
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    /**
     * Exposes a boolean value which can be used to indicate if the object was destroyed.
     * <p/>
     * This is exposing the object, rather than performing the action because we don't want to accidentally
     * form a strong reference to the {@code SwiftInstance} which could prevent the cleanup from running,
     * if using an GC managed instance (e.g. using an {@link AutoSwiftMemorySession}.
     */
    public final AtomicBoolean $statusDestroyedFlag() {
        return this.$state$destroyed;
    }

    /**
     * The designated constructor of any imported Swift types.
     *
     * @param pointer a pointer to the memory containing the value
     * @param arena the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
     */
    protected SwiftInstance(SwiftArena arena) {
        arena.register(this);
    }

    /**
     * Ensures that this instance has not been destroyed.
     * <p/>
     * If this object has been destroyed, calling this method will cause an {@link IllegalStateException}
     * to be thrown. This check should be performed before accessing {@code $memorySegment} to prevent
     * use-after-free errors.
     */
    protected final void $ensureAlive() {
        if (this.$state$destroyed.get()) {
            throw new IllegalStateException("Attempted to call method on already destroyed instance of " + getClass().getSimpleName() + "!");
        }
    }
}
