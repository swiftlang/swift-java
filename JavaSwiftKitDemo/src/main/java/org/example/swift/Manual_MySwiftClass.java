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

package org.example.swift;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.util.Arrays;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import static java.lang.foreign.MemoryLayout.PathElement.groupElement;
import static java.lang.foreign.ValueLayout.OfLong;

/**
 * {@snippet lang = Swift:
 * public class MySwiftClass {
 *     var len: Int
 *     var cap: Int
 * }
 *}
 */
public class Manual_MySwiftClass {

    static final String DYLIB_NAME = "JavaKitExample";
    static final Arena LIBRARY_ARENA = Arena.ofAuto();
    static final boolean TRACE_DOWNCALLS = true || Boolean.getBoolean("jextract.trace.downcalls");


    static void traceDowncall(Object... args) {
        var ex = new RuntimeException();

        String traceArgs = Arrays.stream(args)
                .map(Object::toString)
                .collect(Collectors.joining(", "));
        System.out.printf("[java][%s:%d] %s(%s)\n",
                ex.getStackTrace()[1].getFileName(),
                ex.getStackTrace()[1].getLineNumber(),
                ex.getStackTrace()[1].getMethodName(),
                traceArgs);
    }

    static void trace(Object... args) {
        var ex = new RuntimeException();

        String traceArgs = Arrays.stream(args)
                .map(Object::toString)
                .collect(Collectors.joining(", "));
        System.out.printf("[java][%s:%d] %s: %s\n",
                ex.getStackTrace()[1].getFileName(),
                ex.getStackTrace()[1].getLineNumber(),
                ex.getStackTrace()[1].getMethodName(),
                traceArgs);
    }

    static MemorySegment findOrThrow(String symbol) {
        return SYMBOL_LOOKUP.find(symbol)
                .orElseThrow(() -> new UnsatisfiedLinkError("unresolved symbol: %s".formatted(symbol)));
    }

    static MethodHandle upcallHandle(Class<?> fi, String name, FunctionDescriptor fdesc) {
        try {
            return MethodHandles.lookup().findVirtual(fi, name, fdesc.toMethodType());
        } catch (ReflectiveOperationException ex) {
            throw new AssertionError(ex);
        }
    }

    static MemoryLayout align(MemoryLayout layout, long align) {
        return switch (layout) {
            case PaddingLayout p -> p;
            case ValueLayout v -> v.withByteAlignment(align);
            case GroupLayout g -> {
                MemoryLayout[] alignedMembers = g.memberLayouts().stream()
                        .map(m -> align(m, align)).toArray(MemoryLayout[]::new);
                yield g instanceof StructLayout ?
                        MemoryLayout.structLayout(alignedMembers) : MemoryLayout.unionLayout(alignedMembers);
            }
            case SequenceLayout s -> MemoryLayout.sequenceLayout(s.elementCount(), align(s.elementLayout(), align));
        };
    }

    static final SymbolLookup SYMBOL_LOOKUP =
            SymbolLookup.libraryLookup(System.mapLibraryName(DYLIB_NAME), LIBRARY_ARENA)
                    .or(SymbolLookup.loaderLookup())
                    .or(Linker.nativeLinker().defaultLookup());


    Manual_MySwiftClass() {
        // Should not be called directly
    }


    private static final GroupLayout $LAYOUT = MemoryLayout.structLayout(
            ManualJavaKitExample.SWIFT_INT.withName("heapObject"),
            ManualJavaKitExample.SWIFT_INT.withName("len"),
            ManualJavaKitExample.SWIFT_INT.withName("cap")
    ).withName("$MySwiftClass$31:1"); // TODO: is the name right?

    /**
     * The layout of this class
     */
    public static final GroupLayout layout() {
        return $LAYOUT;
    }

    // --------------------------------------------------------------------------------------------------------
    // ==== len

    private static final OfLong len$LAYOUT = (OfLong)$LAYOUT.select(groupElement("len"));

    private static class len$property {
        public static final FunctionDescriptor DESC_GET = FunctionDescriptor.of(
                /* -> */ManualJavaKitExample.SWIFT_INT,
                /* self = */ ManualJavaKitExample.SWIFT_POINTER
        );
        public static final FunctionDescriptor DESC_SET = FunctionDescriptor.ofVoid(
                /* self = */ ManualJavaKitExample.SWIFT_POINTER,
                ManualJavaKitExample.SWIFT_INT
        );

        private static final String BASE_NAME = "$s14JavaKitExample12MySwiftClassC3lenSiv";
        public static final MemorySegment ADDR_GET = ManualJavaKitExample.findOrThrow(BASE_NAME + "g");
        public static final MemorySegment ADDR_SET = ManualJavaKitExample.findOrThrow(BASE_NAME + "s");

        public static final MethodHandle HANDLE_GET = Linker.nativeLinker().downcallHandle(ADDR_GET, DESC_GET);
        public static final MethodHandle HANDLE_SET = Linker.nativeLinker().downcallHandle(ADDR_SET, DESC_SET);
    }

    public static final OfLong len$layout() {
        return len$LAYOUT;
    }

    private static final long len$OFFSET = 8;

    public static final long len$offset() {
        return len$OFFSET;
    }

    public static FunctionDescriptor len$get$descriptor() {
        return len$property.DESC_GET;
    }
    public static MethodHandle len$get$handle() {
        return len$property.HANDLE_GET;
    }
    public static MemorySegment len$get$address() {
        return len$property.ADDR_GET;
    }

    public static long getLen(MemorySegment self) {
        var mh$ = len$property.HANDLE_GET;
        try {
            if (TRACE_DOWNCALLS) {
                traceDowncall("len$getter", self);
            }
            return (long) mh$.invokeExact(self);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static long getLenRaw(MemorySegment self) {
        // FIXME: seems wrong?
        return self.get(len$LAYOUT, len$OFFSET);
    }


    public static FunctionDescriptor len$set$descriptor() {
        return len$property.DESC_SET;
    }
    public static MethodHandle len$set$handle() {
        return len$property.HANDLE_SET;
    }
    public static MemorySegment len$set$address() {
        return len$property.ADDR_SET;
    }


    /**
     * Setter for field:
     * {@snippet lang = Swift :
     * var len: Int { set }
     * }
     */
    public static void setLen(MemorySegment self, long fieldValue) {
        var mh$ = len$property.HANDLE_SET;
        try {
            if (TRACE_DOWNCALLS) {
                traceDowncall("len$setter", self, fieldValue);
            }
            mh$.invokeExact(self, fieldValue);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }
    public static void setLenRaw(MemorySegment self, long fieldValue) {
        // FIXME: seems wrong?
        self.set(len$LAYOUT, len$OFFSET, fieldValue);
    }

    // --------------------------------------------------------------------------------------------------------
    // ==== len

    private static final OfLong cap$LAYOUT = (OfLong)$LAYOUT.select(groupElement("cap"));

    private static class cap$property {
        public static final FunctionDescriptor DESC_GET = FunctionDescriptor.of(
                /* -> */ManualJavaKitExample.SWIFT_INT,
                /* self = */ ManualJavaKitExample.SWIFT_POINTER
        );
        public static final FunctionDescriptor DESC_SET = FunctionDescriptor.ofVoid(
                /* self = */ ManualJavaKitExample.SWIFT_POINTER,
                ManualJavaKitExample.SWIFT_INT
        );

        private static final String BASE_NAME = "$s14JavaKitExample12MySwiftClassC3capSiv";
        public static final MemorySegment ADDR_GET = ManualJavaKitExample.findOrThrow(BASE_NAME + "g");
        public static final MemorySegment ADDR_SET = ManualJavaKitExample.findOrThrow(BASE_NAME + "s");

        public static final MethodHandle HANDLE_GET = Linker.nativeLinker().downcallHandle(ADDR_GET, DESC_GET);
        public static final MethodHandle HANDLE_SET = Linker.nativeLinker().downcallHandle(ADDR_SET, DESC_SET);
    }

    public static final OfLong cap$layout() {
        return cap$LAYOUT;
    }

    private static final long cap$OFFSET = 16;

    public static final long cap$offset() {
        return cap$OFFSET;
    }

    public static FunctionDescriptor cap$get$descriptor() {
        return cap$property.DESC_GET;
    }
    public static MethodHandle cap$get$handle() {
        return cap$property.HANDLE_GET;
    }
    public static MemorySegment cap$get$address() {
        return cap$property.ADDR_GET;
    }


    // ==== ------------------------------------------------------------------------------------------------------------

    /**
     * Obtains a slice of {@code arrayParam} which selects the array element at {@code index}.
     * The returned segment has address {@code arrayParam.address() + index * layout().byteSize()}
     */
    public static MemorySegment asSlice(MemorySegment array, long index) {
        return array.asSlice(layout().byteSize() * index);
    }

    /**
     * The size (in bytes) of this struct
     */
    public static long sizeof() { return layout().byteSize(); }

    /**
     * Allocate a segment of size {@code layout().byteSize()} using {@code allocator}
     */
    public static MemorySegment allocate(SegmentAllocator allocator) {
        return allocator.allocate(layout());
    }

    /**
     * Allocate an array of size {@code elementCount} using {@code allocator}.
     * The returned segment has size {@code elementCount * layout().byteSize()}.
     */
    public static MemorySegment allocateArray(long elementCount, SegmentAllocator allocator) {
        return allocator.allocate(MemoryLayout.sequenceLayout(elementCount, layout()));
    }

    /**
     * Reinterprets {@code addr} using target {@code arena} and {@code cleanupAction} (if any).
     * The returned segment has size {@code layout().byteSize()}
     */
    public static MemorySegment reinterpret(MemorySegment addr, Arena arena, Consumer<MemorySegment> cleanup) {
        return reinterpret(addr, 1, arena, cleanup);
    }

    /**
     * Reinterprets {@code addr} using target {@code arena} and {@code cleanupAction} (if any).
     * The returned segment has size {@code elementCount * layout().byteSize()}
     */
    public static MemorySegment reinterpret(MemorySegment addr, long elementCount, Arena arena, Consumer<MemorySegment> cleanup) {
        return addr.reinterpret(layout().byteSize() * elementCount, arena, cleanup);
    }
}


