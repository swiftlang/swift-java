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

public abstract class JNISwiftInstance extends SwiftInstance {
    /// Pointer to the "self".
    private final long selfPointer;

    /**
     * The pointer to the instance in memory. I.e. the {@code self} of the Swift object or value.
     */
    public final long pointer() {
        return this.selfPointer;
    }

    /**
     * The designated constructor of any imported Swift types.
     *
     * @param pointer a pointer to the memory containing the value
     * @param arena   the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
     */
    protected JNISwiftInstance(long pointer, SwiftArena arena) {
        super(arena);
        this.selfPointer = pointer;
    }

    /**
     * Creates a function that will be called when the value should be destroyed.
     * This will be code-generated to call a native method to do deinitialization and deallocation.
     * <p>
     * The reason for this "indirection" is that we cannot have static methods on abstract classes,
     * and we can't define the destroy method as a member method, because we assume that the wrapper
     * has been released, when we destroy.
     * <p>
     * <b>Warning:</b> The function must not capture {@code this}.
     *
     * @return a function that is called when the value should be destroyed.
     */
    protected abstract Runnable $createDestroyFunction();

    @Override
    public SwiftInstanceCleanup createCleanupAction() {
        final AtomicBoolean statusDestroyedFlag = $statusDestroyedFlag();
        Runnable markAsDestroyed = new Runnable() {
            @Override
            public void run() {
                statusDestroyedFlag.set(true);
            }
        };

        return new JNISwiftInstanceCleanup(this.$createDestroyFunction(), markAsDestroyed);
    }
}
