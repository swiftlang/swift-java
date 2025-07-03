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

package org.swift.swiftkitffm;

import java.lang.foreign.MemorySegment;

/**
 * A Swift memory instance cleanup, e.g. count-down a reference count and destroy a class, or destroy struct/enum etc.
 */
record SwiftInstanceCleanup(
        MemorySegment selfPointer,
        SwiftAnyType selfType,
        Runnable markAsDestroyed
) implements Runnable {

    @Override
    public void run() {
        markAsDestroyed.run();

        // Allow null pointers just for AutoArena tests.
        if (selfType != null && selfPointer != null) {
            System.out.println("[debug] Destroy swift value [" + selfType.getSwiftName() + "]: " + selfPointer);
            SwiftValueWitnessTable.destroy(selfType, selfPointer);
        }
    }
}