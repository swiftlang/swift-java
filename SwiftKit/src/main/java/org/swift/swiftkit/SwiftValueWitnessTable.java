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

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.VarHandle;

import static java.lang.foreign.ValueLayout.JAVA_BYTE;
import static org.swift.swiftkit.SwiftKit.getSwiftInt;

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
     * Type metadata pointer.
     */
    private static final StructLayout fullTypeMetadataLayout = MemoryLayout.structLayout(
            SwiftValueLayout.SWIFT_POINTER.withName("vwt")
    ).withName("SwiftFullTypeMetadata");

    /**
     * Offset for the "vwt" field within the full type metadata.
     */
    private static final long fullTypeMetadata$vwt$offset =
            fullTypeMetadataLayout.byteOffset(
                    MemoryLayout.PathElement.groupElement("vwt"));

    /**
     * Given the address of Swift type metadata for a type, return the addres
     * of the "full" type metadata that can be accessed via fullTypeMetadataLayout.
     */
    public static MemorySegment fullTypeMetadata(MemorySegment typeMetadata) {
        return MemorySegment.ofAddress(typeMetadata.address() - SwiftValueLayout.SWIFT_POINTER.byteSize())
                .reinterpret(fullTypeMetadataLayout.byteSize());
    }

    /**
     * Given the address of Swift type's metadata, return the address that
     * references the value witness table for the type.
     */
    public static MemorySegment valueWitnessTable(MemorySegment typeMetadata) {
        return fullTypeMetadata(typeMetadata)
                .get(SwiftValueLayout.SWIFT_POINTER, SwiftValueWitnessTable.fullTypeMetadata$vwt$offset);
    }


    /**
     * Offset for the "size" field within the value witness table.
     */
    static final long $size$offset =
            $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("size"));

    /**
     * Variable handle for the "stride" field within the value witness table.
     */
    static final VarHandle $size$mh =
            $LAYOUT.varHandle(MemoryLayout.PathElement.groupElement("size"));

    /**
     * Determine the size of a Swift type given its type metadata.
     *
     * @param typeMetadata the memory segment must point to a Swift metadata
     */
    public static long sizeOfSwiftType(MemorySegment typeMetadata) {
        return getSwiftInt(valueWitnessTable(typeMetadata), $size$mh);
    }

    /**
     * Offset for the "stride" field within the value witness table.
     */
    static final long $stride$offset =
            $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("stride"));

    /**
     * Variable handle for the "stride" field within the value witness table.
     */
    static final VarHandle $stride$mh =
            $LAYOUT.varHandle(MemoryLayout.PathElement.groupElement("stride"));

    /**
     * Determine the stride of a Swift type given its type metadata, which is
     * how many bytes are between successive elements of this type within an
     * array.
     * <p>
     * It is >= the size.
     *
     * @param typeMetadata the memory segment must point to a Swift metadata
     */
    public static long strideOfSwiftType(MemorySegment typeMetadata) {
        return getSwiftInt(valueWitnessTable(typeMetadata), $stride$mh);
    }


    /**
     * Determine the alignment of the given Swift type.
     *
     * @param typeMetadata the memory segment must point to a Swift metadata
     */
    public static long alignmentOfSwiftType(MemorySegment typeMetadata) {
        long flags = getSwiftInt(valueWitnessTable(typeMetadata), $flags$offset);
        return (flags & 0xFF) + 1;
    }

    /**
     * Produce a layout that describes a Swift type based on its
     * type metadata. The resulting layout is completely opaque to Java, but
     * has appropriate size/alignment to model the memory associated with a
     * Swift type.
     * <p>
     * In the future, this layout could be extended to provide more detail,
     * such as the fields of a Swift struct.
     *
     * @param typeMetadata the memory segment must point to a Swift metadata
     */
    public static MemoryLayout layoutOfSwiftType(MemorySegment typeMetadata) {
        long size = sizeOfSwiftType(typeMetadata);
        long stride = strideOfSwiftType(typeMetadata);
        long padding = stride - size;

        // constructing a zero-length paddingLayout is illegal, so we avoid doing so
        MemoryLayout[] layouts = padding == 0 ?
                new MemoryLayout[]{
                        MemoryLayout.sequenceLayout(size, JAVA_BYTE)
                                .withByteAlignment(alignmentOfSwiftType(typeMetadata))
                } :
                new MemoryLayout[]{
                        MemoryLayout.sequenceLayout(size, JAVA_BYTE)
                                .withByteAlignment(alignmentOfSwiftType(typeMetadata)),
                        MemoryLayout.paddingLayout(stride - size)
                };

        return MemoryLayout.structLayout(
                layouts
        ).withName(SwiftKit.nameOfSwiftType(typeMetadata, true));
    }


    /**
     * Offset for the "flags" field within the value witness table.
     */
    static final long $flags$offset =
            $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("flags"));

    // ==== ------------------------------------------------------------------------------------------------------------
    // destroy

    /**
     * {@snippet lang = C:
     * ///    void(*destroy)(T *object, witness_t *self);
     * ///
     * /// Given a valid object of this type, destroy it, leaving it as an
     * /// invalid object. This is useful when generically destroying
     * /// an object which has been allocated in-line, such as an array,
     * /// struct,or tuple element.
     * FUNCTION_VALUE_WITNESS(destroy,
     *   Destroy,
     *   VOID_TYPE,
     *   (MUTABLE_VALUE_TYPE, TYPE_TYPE))
     *}
     */
    private static class destroy {

        static final long $offset =
                $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("destroy"));

        static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
                ValueLayout.ADDRESS, // witness table functions expect a pointer to self pointer
                ValueLayout.ADDRESS // pointer to the witness table
        );

        /**
         * Function pointer for the destroy operation
         */
        static MemorySegment addr(SwiftAnyType ty) {
            // Get the value witness table of the type
            final var vwt = SwiftValueWitnessTable.valueWitnessTable(ty.$memorySegment());

            // Get the address of the destroy function stored at the offset of the witness table
            long funcAddress = getSwiftInt(vwt, destroy.$offset);
            return MemorySegment.ofAddress(funcAddress);
        }

        static MethodHandle handle(SwiftAnyType ty) {
            return Linker.nativeLinker().downcallHandle(addr(ty), DESC);
        }
    }

    /**
     * Destroy the value/object.
     * <p>
     * This includes deallocating the Swift managed memory for the object.
     */
    public static void destroy(SwiftAnyType type, MemorySegment object) {
        var fullTypeMetadata = fullTypeMetadata(type.$memorySegment());
        var wtable = valueWitnessTable(fullTypeMetadata);

        var mh = destroy.handle(type);

        try (var arena = Arena.ofConfined()) {
            // we need to make a pointer to the self pointer when calling witness table functions:
            MemorySegment indirect = arena.allocate(SwiftValueLayout.SWIFT_POINTER); // TODO: remove this and just have classes have this always anyway
            MemorySegmentUtils.setSwiftPointerAddress(indirect, object);

            mh.invokeExact(indirect, wtable);
        } catch (Throwable th) {
            throw new AssertionError("Failed to destroy '" + type + "' at " + object, th);
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // initializeWithCopy

    /**
     * {@snippet lang = C:
     * ///   T *(*initializeWithCopy)(T *dest, T *src, M *self);
     * ///
     * /// Given an invalid object of this type, initialize it as a copy of
     * /// the source object.  Returns the dest object.
     * FUNCTION_VALUE_WITNESS(initializeWithCopy,
     *                        InitializeWithCopy,
     *                        MUTABLE_VALUE_TYPE,
     *                        (MUTABLE_VALUE_TYPE, MUTABLE_VALUE_TYPE, TYPE_TYPE))
     *}
     */
    private static class initializeWithCopy {
        static final long $offset =
                $LAYOUT.byteOffset(MemoryLayout.PathElement.groupElement("destroy"));

        static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
                ValueLayout.ADDRESS, // witness table functions expect a pointer to self pointer
                ValueLayout.ADDRESS // pointer to the witness table
        );

        /**
         * Function pointer for the destroy operation
         */
        static MemorySegment addr(SwiftAnyType ty) {
            // Get the value witness table of the type
            final var vwt = SwiftValueWitnessTable.valueWitnessTable(ty.$memorySegment());

            // Get the address of the destroy function stored at the offset of the witness table
            long funcAddress = getSwiftInt(vwt, destroy.$offset);
            return MemorySegment.ofAddress(funcAddress);
        }

        static MethodHandle handle(SwiftAnyType ty) {
            return Linker.nativeLinker().downcallHandle(addr(ty), DESC);
        }
    }

    public static void initializeWithCopy(SwiftAnyType type, MemorySegment from, MemorySegment target) {

    }
}
