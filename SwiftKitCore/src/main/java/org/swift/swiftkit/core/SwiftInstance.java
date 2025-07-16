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
     * The designated constructor of any imported Swift types.
     *
     * @param arena the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
     */
    protected SwiftInstance(SwiftArena arena) {
        arena.register(this);
    }

    /**
     * Pointer to the {@code self} of the underlying Swift object or value.
     *
     * @apiNote When using this pointer one must ensure that the underlying object
     *          is kept alive using some means (e.g. a class remains retained), as
     *          this function does not ensure safety of the address in any way.
     */
    public abstract long $memoryAddress();

    /**
     * Called when the arena has decided the value should be destroyed.
     * <p/>
     * <b>Warning:</b> The cleanup action must not capture {@code this}.
     */
    public abstract SwiftInstanceCleanup $createCleanup();

    /**
     * Exposes a boolean value which can be used to indicate if the object was destroyed.
     * <p/>
     * This is exposing the object, rather than performing the action because we don't want to accidentally
     * form a strong reference to the {@code SwiftInstance} which could prevent the cleanup from running,
     * if using an GC managed instance (e.g. using an {@code AutoSwiftMemorySession}.
     */
    public final AtomicBoolean $statusDestroyedFlag() {
        return this.$state$destroyed;
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
