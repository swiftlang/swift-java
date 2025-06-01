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

import java.lang.foreign.GroupLayout;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;

public final class SwiftAnyType {

    private static final GroupLayout $LAYOUT = MemoryLayout.structLayout(
            SwiftValueLayout.SWIFT_POINTER
    );

    private final MemorySegment memorySegment;

    public SwiftAnyType(MemorySegment memorySegment) {
//        if (SwiftKit.getSwiftInt(memorySegment, 0) > 0) {
//            throw new IllegalArgumentException("A Swift Any.Type cannot be null!");
//        }

        this.memorySegment = memorySegment.asReadOnly();
    }

    public MemorySegment $memorySegment() {
        return memorySegment;
    }

    public GroupLayout $layout() {
        return $LAYOUT;
    }

    /**
     * Get the human-readable Swift type name of this type.
     */
    public String getSwiftName() {
        return SwiftKit.nameOfSwiftType(memorySegment, true);
    }

    @Override
    public String toString() {
        return "AnySwiftType{" +
                "name=" + getSwiftName() +
                ", memorySegment=" + memorySegment +
                '}';
    }

}
