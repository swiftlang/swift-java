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
 * A Swift memory resource cleanup, e.g. count-down a reference count and destroy a class, or destroy struct/enum etc.
 */
sealed interface SwiftMemoryResourceCleanup extends Runnable {
}

record SwiftHeapObjectCleanup(MemorySegment resource) implements SwiftMemoryResourceCleanup {

    @Override
    public void run() throws UnexpectedRetainCountException {
        long retainedCount = SwiftKit.retainCount(this.resource);
        if (retainedCount > 1) {
            throw new UnexpectedRetainCountException(this.resource, retainedCount, 1);
        }

        SwiftKit.log.info("Destroy heap object: " + this.resource);

        SwiftValueWitnessTable.destroy(this.resource);
    }
}

record SwiftValueCleanup(MemorySegment resource) implements SwiftMemoryResourceCleanup {
    @Override
    public void run() {
        throw new RuntimeException("not implemented yet");
    }
}
