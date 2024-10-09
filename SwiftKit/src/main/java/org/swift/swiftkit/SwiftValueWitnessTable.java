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

import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.StructLayout;
import java.lang.foreign.ValueLayout;

public abstract class SwiftValueWitnessTable {
    /**
     * Value witness table layout.
     */
    public static final MemoryLayout $LAYOUT = MemoryLayout.structLayout(
            ValueLayout.ADDRESS.withName("initializeBufferWithCopyOfBuffer"),
            ValueLayout.ADDRESS.withName("destroy"),
            ValueLayout.ADDRESS.withName("initializeWithCopy"),
            ValueLayout.ADDRESS.withName("assignWithCopy"),
            ValueLayout.ADDRESS.withName("initializeWithTake"),
            ValueLayout.ADDRESS.withName("assignWithTake"),
            ValueLayout.ADDRESS.withName("getEnumTagSinglePayload"),
            ValueLayout.ADDRESS.withName("storeEnumTagSinglePayload"),
            SwiftValueLayout.SWIFT_INT.withName("size"),
            SwiftValueLayout.SWIFT_INT.withName("stride"),
            SwiftValueLayout.SWIFT_UINT.withName("flags"),
            SwiftValueLayout.SWIFT_UINT.withName("extraInhabitantCount")
    ).withName("SwiftValueWitnessTable");


    /**
     * Offset for the "size" field within the value witness table.
     */
    static final long $size$offset =
            $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("size"));

    /**
     * Offset for the "stride" field within the value witness table.
     */
    static final long $stride$offset =
            $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("stride"));

    /**
     * Offset for the "flags" field within the value witness table.
     */
    static final long $flags$offset =
            $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("flags"));

    /**
     * Type metadata pointer.
     */
    static final StructLayout fullTypeMetadataLayout = MemoryLayout.structLayout(
            SwiftValueLayout.SWIFT_POINTER.withName("vwt")
    ).withName("SwiftFullTypeMetadata");

    /**
     * Offset for the "vwt" field within the full type metadata.
     */
    static final long fullTypeMetadata$vwt$offset =
            fullTypeMetadataLayout.byteOffset(MemoryLayout.PathElement.groupElement("vwt"));

    private static class destroy {
        static final long $offset =
                $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("destroy"));
    }

}
