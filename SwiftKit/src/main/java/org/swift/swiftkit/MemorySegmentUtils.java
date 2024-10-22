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
import java.lang.foreign.ValueLayout;

public class MemorySegmentUtils {
    /**
     * Set the value of `target` to the {@link MemorySegment#address()} of the `memorySegment`,
     * adjusting for the fact that Swift pointer may be 32 or 64 bit, depending on runtime.
     *
     * @param target        the target to set a value on
     * @param memorySegment the origin of the address value to write into `target`
     */
    static void setSwiftPointerAddress(MemorySegment target, MemorySegment memorySegment) {
        // Write the address of as the value of the newly created pointer.
        // We need to type-safely set the pointer value which may be 64 or 32-bit.
        if (SwiftValueLayout.SWIFT_INT == ValueLayout.JAVA_LONG) {
            System.out.println("[setSwiftPointerAddress] address is long = " + memorySegment.address());
            target.set(ValueLayout.JAVA_LONG, /*offset=*/0, memorySegment.address());
        } else {
            System.out.println("[setSwiftPointerAddress] address is int = " + memorySegment.address());
            target.set(ValueLayout.JAVA_INT, /*offset=*/0, (int) memorySegment.address());
        }
    }
}
