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

public class FFMSwiftInstanceCleanup implements SwiftInstanceCleanup {
    private final MemorySegment memoryAddress;
    private final SwiftAnyType type;
    private final Runnable markAsDestroyed;

    public FFMSwiftInstanceCleanup(MemorySegment memoryAddress, SwiftAnyType type, Runnable markAsDestroyed) {
        this.memoryAddress = memoryAddress;
        this.type = type;
        this.markAsDestroyed = markAsDestroyed;
    }

    @Override
    public void run() {
        markAsDestroyed.run();

        // Allow null pointers just for AutoArena tests.
        if (type != null && memoryAddress != null) {
            SwiftRuntime.log(LIFECYCLE, "Destroy swift value [" + type.getSwiftName() + "]: " + memoryAddress);
            SwiftValueWitnessTable.destroy(type, memoryAddress);
        }
    }
}
