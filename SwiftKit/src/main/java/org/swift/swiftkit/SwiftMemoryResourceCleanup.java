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
sealed interface SwiftMemoryResourceCleanup extends Runnable {
}

record SwiftHeapObjectCleanup(SwiftHeapObject instance) implements SwiftMemoryResourceCleanup {

    @Override
    public void run() throws UnexpectedRetainCountException {
        // Verify we're only destroying an object that's indeed not retained by anyone else:
        long retainedCount = SwiftKit.retainCount(this.instance);
        if (retainedCount > 1) {
            throw new UnexpectedRetainCountException(this.instance, retainedCount, 1);
        }

        // Destroy (and deinit) the object:
        var ty = this.instance.$swiftType();
        SwiftValueWitnessTable.destroy(ty, this.instance.$memorySegment());

        // Invalidate the Java wrapper class, in order to prevent effectively use-after-free issues.
        // FIXME: some trouble with setting the pointer to null, need to figure out an appropriate way to do this
    }
}

record SwiftValueCleanup(MemorySegment resource) implements SwiftMemoryResourceCleanup {
    @Override
    public void run() {
        throw new RuntimeException("not implemented yet");
    }
}
