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

package org.swift.javakit;

import org.swift.swiftkit.SwiftHeapObject;

import java.lang.foreign.*;
import java.lang.foreign.MemoryLayout.PathElement;
import java.lang.invoke.MethodHandle;
import java.util.Arrays;
import java.util.stream.Collectors;

import static java.lang.foreign.ValueLayout.ADDRESS;
import static java.lang.foreign.ValueLayout.JAVA_BYTE;

public class SwiftKit {

    // FIXME: why do we need to hardcore the path, seems it can't find by name
     private static final String STDLIB_DYLIB_NAME = "swiftCore";
    private static final String STDLIB_DYLIB_PATH = "/usr/lib/swift/libswiftCore.dylib";

    private static final Arena LIBRARY_ARENA = Arena.ofAuto();
    static final boolean TRACE_DOWNCALLS = Boolean.getBoolean("jextract.trace.downcalls");

    static {
        System.loadLibrary(STDLIB_DYLIB_NAME);
    }

    public static final AddressLayout SWIFT_POINTER = ValueLayout.ADDRESS
            .withTargetLayout(MemoryLayout.sequenceLayout(java.lang.Long.MAX_VALUE, JAVA_BYTE));

    static final SymbolLookup SYMBOL_LOOKUP =
            // FIXME: why does this not find just by name?
            // SymbolLookup.libraryLookup(System.mapLibraryName(STDLIB_DYLIB_NAME), LIBRARY_ARENA)
            SymbolLookup.libraryLookup(STDLIB_DYLIB_PATH, LIBRARY_ARENA)
                    .or(SymbolLookup.loaderLookup())
                    .or(Linker.nativeLinker().defaultLookup());

    public SwiftKit() {
    }

    static void traceDowncall(String name, Object... args) {
        String traceArgs = Arrays.stream(args)
                .map(Object::toString)
                .collect(Collectors.joining(", "));
        System.out.printf("%s(%s)\n", name, traceArgs);
    }

    static MemorySegment findOrThrow(String symbol) {
        return SYMBOL_LOOKUP.find(symbol)
                .orElseThrow(() -> new UnsatisfiedLinkError("unresolved symbol: %s".formatted(symbol)));
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // free
    /**
     * Descriptor for the free C runtime function.
     */
    public static final FunctionDescriptor free$descriptor = FunctionDescriptor.ofVoid(
        ValueLayout.ADDRESS
    );

    /**
     * Address of the free C runtime function.
     */
    public static final MemorySegment free$addr = findOrThrow("free");

    /**
     * Handle for the free C runtime function.
     */
    public static final MethodHandle free$handle = Linker.nativeLinker().downcallHandle(free$addr, free$descriptor);

    /**
     * free the given pointer
     */
    public static void cFree(MemorySegment pointer) {
        try {
            free$handle.invokeExact(pointer);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // swift_retainCount

    private static class swift_retainCount {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /*returns=*/ValueLayout.JAVA_LONG,
                ValueLayout.ADDRESS
        );

        public static final MemorySegment ADDR = findOrThrow("swift_retainCount");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }


    public static long retainCount(MemorySegment object) {
        var mh$ = swift_retainCount.HANDLE;
        try {
            if (TRACE_DOWNCALLS) {
                traceDowncall("swift_retainCount", object);
            }
            return (long) mh$.invokeExact(object);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static long retainCount(SwiftHeapObject object) {
        return retainCount(object.$self());
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // swift_retain

    private static class swift_retain {
        public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
                ValueLayout.ADDRESS
        );

        public static final MemorySegment ADDR = findOrThrow("swift_retain");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }


    public static void retain(MemorySegment object) {
        var mh$ = swift_retain.HANDLE;
        try {
            if (TRACE_DOWNCALLS) {
                traceDowncall("swift_retain", object);
            }
            mh$.invokeExact(object);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static long retain(SwiftHeapObject object) {
        return retainCount(object.$self());
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // swift_release

    private static class swift_release {
        public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
                ValueLayout.ADDRESS
        );

        public static final MemorySegment ADDR = findOrThrow("swift_release");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }


    public static void release(MemorySegment object) {
        var mh$ = swift_release.HANDLE;
        try {
            if (TRACE_DOWNCALLS) {
                traceDowncall("swift_release_retain", object);
            }
            mh$.invokeExact(object);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static long release(SwiftHeapObject object) {
        return retainCount(object.$self());
    }

    // ==== ------------------------------------------------------------------------------------------------------------

    /**
     * {@snippet lang=swift :
     * func _typeByName(_: Swift.String) -> Any.Type?
     * }
     */
    private static class swift_getTypeByName {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /*returns=*/ValueLayout.ADDRESS,
                ValueLayout.ADDRESS,
                ValueLayout.JAVA_INT
        );

        public static final MemorySegment ADDR = findOrThrow("$ss11_typeByNameyypXpSgSSF");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }

    public static MemorySegment getTypeByName(String string) {
        var mh$ = swift_getTypeByName.HANDLE;
        try {
            if (TRACE_DOWNCALLS) {
                traceDowncall("_swift_getTypeByName");
            }
            // TODO: A bit annoying to generate, we need an arena for the conversion...
            try (Arena arena = Arena.ofConfined()) {
                MemorySegment stringMemorySegment = arena.allocateFrom(string);

                return (MemorySegment) mh$.invokeExact(stringMemorySegment, string.length());
            }
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    /**
     * {@snippet lang=swift :
     * func _swift_getTypeByMangledNameInEnvironment(
     *     _ name: UnsafePointer<UInt8>,
     *     _ nameLength: UInt,
     *     genericEnvironment: UnsafeRawPointer?,
     *     genericArguments: UnsafeRawPointer?
     * ) -> Any.Type?
     * }
     */
    private static class swift_getTypeByMangledNameInEnvironment {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /*returns=*/SWIFT_POINTER,
                ValueLayout.ADDRESS,
                ValueLayout.JAVA_INT,
                ValueLayout.ADDRESS,
                ValueLayout.ADDRESS
        );

        public static final MemorySegment ADDR = findOrThrow("swift_getTypeByMangledNameInEnvironment");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }

    public static MemorySegment getTypeByMangledNameInEnvironment(String string) {
        var mh$ = swift_getTypeByMangledNameInEnvironment.HANDLE;
        try {
            if (string.endsWith("CN")) {
                string = string.substring(0, string.length() - 2);
            }
            if (TRACE_DOWNCALLS) {
                traceDowncall(string);
            }
            try (Arena arena = Arena.ofConfined()) {
                MemorySegment stringMemorySegment = arena.allocateFrom(string);

                return (MemorySegment) mh$.invokeExact(stringMemorySegment, string.length(), MemorySegment.NULL, MemorySegment.NULL);
            }
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    /**
     * The value layout for Swift's Int type, which is a signed type that follows
     * the size of a pointer (aka C's ptrdiff_t).
     */
    public static ValueLayout SWIFT_INT = (ValueLayout.ADDRESS.byteSize() == 4) ?
        ValueLayout.JAVA_INT : ValueLayout.JAVA_LONG;

    /**
     * The value layout for Swift's UInt type, which is an unsigned type that follows
     * the size of a pointer (aka C's size_t). Java does not have unsigned integer
     * types in general, so we use the layout for Swift's Int.
     */
    public static ValueLayout SWIFT_UINT = SWIFT_INT;

    /**
     * Read a Swift.Int value from memory at the given offset and translate it into a Java long.
     *
     * This function copes with the fact that a Swift.Int might be 32 or 64 bits.
     */
    public static final long getSwiftInt(MemorySegment memorySegment, long offset) {
        if (SWIFT_INT == ValueLayout.JAVA_LONG) {
            return memorySegment.get(ValueLayout.JAVA_LONG, offset);
        } else {
            return memorySegment.get(ValueLayout.JAVA_INT, offset);
        }
    }

    /**
     * Value witness table layout.
     */
    public static final MemoryLayout valueWitnessTableLayout = MemoryLayout.structLayout(
        ValueLayout.ADDRESS.withName("initializeBufferWithCopyOfBuffer"),
        ValueLayout.ADDRESS.withName("destroy"),
        ValueLayout.ADDRESS.withName("initializeWithCopy"),
        ValueLayout.ADDRESS.withName("assignWithCopy"),
        ValueLayout.ADDRESS.withName("initializeWithTake"),
        ValueLayout.ADDRESS.withName("assignWithTake"),
        ValueLayout.ADDRESS.withName("getEnumTagSinglePayload"),
        ValueLayout.ADDRESS.withName("storeEnumTagSinglePayload"),
        SwiftKit.SWIFT_INT.withName("size"),
        SwiftKit.SWIFT_INT.withName("stride"),
        SwiftKit.SWIFT_UINT.withName("flags"),
        SwiftKit.SWIFT_UINT.withName("extraInhabitantCount")
    ).withName("SwiftValueWitnessTable");

    /**
     * Offset for the "size" field within the value witness table.
     */
    static final long valueWitnessTable$size$offset =
        valueWitnessTableLayout.byteOffset(PathElement.groupElement("size"));

    /**
     * Offset for the "stride" field within the value witness table.
     */
    static final long valueWitnessTable$stride$offset =
        valueWitnessTableLayout.byteOffset(PathElement.groupElement("stride"));

    /**
     * Offset for the "flags" field within the value witness table.
     */
    static final long valueWitnessTable$flags$offset =
        valueWitnessTableLayout.byteOffset(PathElement.groupElement("flags"));

    /**
     * Type metadata pointer.
     */
    public static final StructLayout fullTypeMetadataLayout = MemoryLayout.structLayout(
        SWIFT_POINTER.withName("vwt")
    ).withName("SwiftFullTypeMetadata");

    /**
     * Offset for the "vwt" field within the full type metadata.
     */
    static final long fullTypeMetadata$vwt$offset =
        fullTypeMetadataLayout.byteOffset(PathElement.groupElement("vwt"));

    /**
     * Given the address of Swift type metadata for a type, return the addres
     * of the "full" type metadata that can be accessed via fullTypeMetadataLayout.
     */
    public static MemorySegment fullTypeMetadata(MemorySegment typeMetadata) {
        return MemorySegment.ofAddress(typeMetadata.address() - SWIFT_POINTER.byteSize())
            .reinterpret(fullTypeMetadataLayout.byteSize());
    }

    /**
     * Given the address of Swift type's metadata, return the address that
     * references the value witness table for the type.
     */
    public static MemorySegment valueWitnessTable(MemorySegment typeMetadata) {
        return fullTypeMetadata(typeMetadata).get(SWIFT_POINTER, fullTypeMetadata$vwt$offset);
    }

    /**
     * Determine the size of a Swift type given its type metadata.
     */
    public static long sizeOfSwiftType(MemorySegment typeMetadata) {
        return getSwiftInt(valueWitnessTable(typeMetadata), valueWitnessTable$size$offset);
    }

    /**
     * Determine the stride of a Swift type given its type metadata, which is
     * how many bytes are between successive elements of this type within an
     * array. It is >= the size.
     */
    public static long strideOfSwiftType(MemorySegment typeMetadata) {
        return getSwiftInt(valueWitnessTable(typeMetadata), valueWitnessTable$stride$offset);
    }

    /**
     * Determine the alignment of the given Swift type.
     */
    public static long alignmentOfSwiftType(MemorySegment typeMetadata) {
        long flags = getSwiftInt(valueWitnessTable(typeMetadata), valueWitnessTable$flags$offset);
        return (flags & 0xFF) + 1;
    }

    /**
     * Descriptor for the swift_getTypeName runtime function.
     */
    public static final FunctionDescriptor swift_getTypeName$descriptor = FunctionDescriptor.of(
        /*returns=*/MemoryLayout.structLayout(
            SWIFT_POINTER.withName("utf8Chars"),
            SWIFT_INT.withName("length")
        ),
        ValueLayout.ADDRESS,
        ValueLayout.JAVA_BOOLEAN
    );

    /**
     * Address of the swift_getTypeName runtime function.
     */
    public static final MemorySegment swift_getTypeName$addr = findOrThrow("swift_getTypeName");

    /**
     * Handle for the swift_getTypeName runtime function.
     */
    public static final MethodHandle swift_getTypeName$handle = Linker.nativeLinker().downcallHandle(swift_getTypeName$addr, swift_getTypeName$descriptor);

    /**
     * Produce the name of the Swift type given its Swift type metadata.
     *
     * If 'qualified' is true, leave all of the qualification in place to
     * disambiguate the type, producing a more complete (but longer) type name.
     */
    public static String nameOfSwiftType(MemorySegment typeMetadata, boolean qualified) {
        try {
            try (Arena arena = Arena.ofConfined()) {
              MemorySegment charsAndLength = (MemorySegment)swift_getTypeName$handle.invokeExact((SegmentAllocator)arena, typeMetadata, qualified);
              MemorySegment utf8Chars = charsAndLength.get(SWIFT_POINTER, 0);
              String typeName = utf8Chars.getString(0);
              cFree(utf8Chars);
              return typeName;
            }
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    /**
     * Produce a layout that describes a Swift type based on its
     * type metadata. The resulting layout is completely opaque to Java, but
     * has appropriate size/alignment to model the memory associated with a
     * Swift type.
     *
     * In the future, this layout could be extended to provide more detail,
     * such as the fields of a Swift struct.
     */
    public static MemoryLayout layoutOfSwiftType(MemorySegment typeMetadata) {
        long size = sizeOfSwiftType(typeMetadata);
        long stride = strideOfSwiftType(typeMetadata);
        return MemoryLayout.structLayout(
            MemoryLayout.sequenceLayout(size, JAVA_BYTE)
              .withByteAlignment(alignmentOfSwiftType(typeMetadata)),
            MemoryLayout.paddingLayout(stride - size)
        ).withName(nameOfSwiftType(typeMetadata, true));
    }
}
