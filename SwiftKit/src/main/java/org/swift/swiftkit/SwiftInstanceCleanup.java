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

import java.lang.foreign.MemorySegment;

/**
 * A Swift memory instance cleanup, e.g. count-down a reference count and destroy a class, or destroy struct/enum etc.
 */
interface SwiftInstanceCleanup extends Runnable {
}

/**
 * Implements cleaning up a Swift {@link SwiftHeapObject}.
 * <p>
 * This class does not store references to the Java wrapper class, and therefore the wrapper may be subject to GC,
 * which may trigger a cleanup (using this class), which will clean up its underlying native memory resource.
 */
// non-final for testing
class SwiftHeapObjectCleanup implements SwiftInstanceCleanup {

    private final MemorySegment selfPointer;
    private final SwiftAnyType selfType;
    private final Runnable markAsDestroyed;

    /**
     * This constructor on purpose does not just take a {@link SwiftHeapObject} in order to make it very
     * clear that it does not take ownership of it, but we ONLY manage the native resource here.
     * </p>
     * This is important for {@link AutoSwiftMemorySession} which relies on the wrapper type to be GC-able,
     * when no longer "in use" on the Java side.
     */
    SwiftHeapObjectCleanup(MemorySegment selfPointer,
                           SwiftAnyType selfType, Runnable markAsDestroyed) {
        this.selfPointer  = selfPointer;
        this.markAsDestroyed = markAsDestroyed;
        this.selfType = selfType;
    }

    @Override
    public void run() throws UnexpectedRetainCountException {
        // Verify we're only destroying an object that's indeed not retained by anyone else:
        long retainedCount = SwiftKit.retainCount(selfPointer);
        if (retainedCount > 1) {
            throw new UnexpectedRetainCountException(selfPointer, retainedCount, 1);
        }

        this.markAsDestroyed.run();

        // Destroy (and deinit) the object:
        SwiftValueWitnessTable.destroy(selfType, selfPointer);

        // Invalidate the Java wrapper class, in order to prevent effectively use-after-free issues.
        // FIXME: some trouble with setting the pointer to null, need to figure out an appropriate way to do this
    }
}

record SwiftValueCleanup(
        MemorySegment selfPointer,
        SwiftAnyType selfType,
        Runnable markAsDestroyed
) implements SwiftInstanceCleanup {

    @Override
    public void run() {
        System.out.println("[debug] Destroy swift value [" + selfType.getSwiftName() + "]: " + selfPointer);

        markAsDestroyed.run();
        SwiftValueWitnessTable.destroy(selfType, selfPointer);
    }
}
