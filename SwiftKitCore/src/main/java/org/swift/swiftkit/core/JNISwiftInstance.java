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

import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;

public abstract class JNISwiftInstance extends SwiftInstance {
    // Pointer to the "self".
    protected final long selfPointer;

    /**
     * The designated constructor of any imported Swift types.
     *
     * @param selfPointer a pointer to the memory containing the value
     * @param arena   the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
     */
    protected JNISwiftInstance(long selfPointer, SwiftArena arena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        this.selfPointer = selfPointer;

        // Only register once we have fully initialized the object since this will need the object pointer.
        arena.register(this);
    }

    @Override
    public long $memoryAddress() {
        return this.selfPointer;
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
    public SwiftInstanceCleanup $createCleanup() {
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
