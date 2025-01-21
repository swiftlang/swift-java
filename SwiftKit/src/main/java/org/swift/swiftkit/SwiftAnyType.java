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

    public static SwiftAnyType SWIFT_INT = SwiftKit.getTypeByMangledNameInEnvironment("SiSg").get();
    public static SwiftAnyType SWIFT_UINT = SwiftKit.getTypeByMangledNameInEnvironment("SuSg").get();
    public static SwiftAnyType SWIFT_LONG = SwiftKit.getTypeByMangledNameInEnvironment("SiSg").get();
    public static SwiftAnyType SWIFT_BOOL = SwiftKit.getTypeByMangledNameInEnvironment("SbSg").get();
    public static SwiftAnyType SWIFT_DOUBLE = SwiftKit.getTypeByMangledNameInEnvironment("SdSg").get();
    public static SwiftAnyType SWIFT_FLOAT = SwiftKit.getTypeByMangledNameInEnvironment("SfSg").get();
    public static SwiftAnyType SWIFT_UNSAFE_RAW_POINTER = SwiftKit.getTypeByMangledNameInEnvironment("SVSg").get();
    public static SwiftAnyType SWIFT_UNSAFE_MUTABLE_RAW_POINTER = SwiftKit.getTypeByMangledNameInEnvironment("SvSg").get();
    public static SwiftAnyType SWIFT_string = SwiftKit.getTypeByMangledNameInEnvironment("SSg").get();

    public SwiftAnyType(MemorySegment memorySegment) {
        this.memorySegment = memorySegment.asReadOnly();
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
