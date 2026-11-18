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

package org.swift.swiftkit.ffm;

import org.swift.swiftkit.core.SwiftInstanceCleanup;

import static org.swift.swiftkit.ffm.SwiftJavaLogGroup.LIFECYCLE;

import java.lang.foreign.MemorySegment;
import java.util.concurrent.atomic.AtomicIntegerFieldUpdater;

class FFMSwiftInstanceCleanup implements SwiftInstanceCleanup {
    private static final AtomicIntegerFieldUpdater<FFMSwiftInstanceCleanup> DESTROYED =
            AtomicIntegerFieldUpdater.newUpdater(FFMSwiftInstanceCleanup.class, "destroyed");

    private final FFMInstanceMemory memoryAddress;
    private final SwiftAnyType type;

    @SuppressWarnings("unused") // accessed via DESTROYED field updater
    private volatile int destroyed;

    public FFMSwiftInstanceCleanup(FFMInstanceMemory memoryAddress, SwiftAnyType type) {
        this.memoryAddress = memoryAddress;
        this.type = type;
    }

    @Override
    public boolean isDestroyed() {
        return destroyed != 0;
    }

    @Override
    public void run() {
        if (DESTROYED.compareAndSet(this, 0, 1)) {
            MemorySegment address = memoryAddress != null ? memoryAddress.get() : null;
            // Allow null pointers just for AutoArena tests.
            if (type != null && address != null) {
                SwiftRuntime.log(LIFECYCLE, "Destroy swift value [" + type.getSwiftName() + "]: " + address);
                SwiftValueWitnessTable.destroy(type, address);
            }
            if (memoryAddress != null) {
                memoryAddress.clear();
            }
        } else {
            throw new IllegalStateException("Double destruction attempt detected!");
        }
    }
}
