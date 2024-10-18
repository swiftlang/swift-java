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
        if (memorySegment.byteSize() == 0) {
            throw new IllegalArgumentException("A Swift Any.Type cannot be null!");
        }

        this.memorySegment = memorySegment;
    }

    public SwiftAnyType(SwiftHeapObject object) {
        if (object.$layout().name().isEmpty()) {
            throw new IllegalArgumentException("SwiftHeapObject must have a mangled name in order to obtain its SwiftType.");
        }

        String mangledName = object.$layout().name().get();
        var type = SwiftKit.getTypeByMangledNameInEnvironment(mangledName);
        if (type.isEmpty()) {
            throw new IllegalArgumentException("A Swift Any.Type cannot be null!");
        }
        this.memorySegment = type.get().memorySegment;
    }


    public MemorySegment $memorySegment() {
        return memorySegment;
    }

    public GroupLayout $layout() {
        return $LAYOUT;
    }

    @Override
    public String toString() {
        return "AnySwiftType{" +
                "name=" + SwiftKit.nameOfSwiftType(memorySegment, true) +
                ", memorySegment=" + memorySegment +
                '}';
    }
}
