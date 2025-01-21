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
import java.util.function.Function;

import static org.swift.swiftkit.SwiftValueLayout.SWIFT_INT;
import static org.swift.swiftkit.SwiftValueLayout.SWIFT_POINTER;

public class SwiftArrayRef<Wrapped extends SwiftInstance> {

    private final MemorySegment self$;
    private final SwiftAnyType wrappedType;
    private final Function<MemorySegment, Wrapped> wrapAsWrapped;

    private GroupLayout ELEMENT_LAYOUT = null;
    private SequenceLayout ARRAY_OF_ELEMENT_LAYOUT = null;

    public SwiftArrayRef(Arena arena,
                         MemorySegment selfMemorySegment,
                         SwiftAnyType wrappedSwiftTypeMetadata,
                         Function<MemorySegment, Wrapped> memorySegmentAsWrapped) {
        this.self$ = selfMemorySegment;
        this.wrappedType = wrappedSwiftTypeMetadata;
        this.wrapAsWrapped = memorySegmentAsWrapped;

        this.ELEMENT_LAYOUT = (GroupLayout) SwiftValueWitnessTable.layoutOfSwiftType(wrappedType.$memorySegment());
        this.ARRAY_OF_ELEMENT_LAYOUT = MemoryLayout.sequenceLayout(this.count(), ELEMENT_LAYOUT);
    }

    public final MemorySegment $memorySegment() {
        return this.self$;
    }

    @SuppressWarnings("unused")
    private static final boolean INITIALIZED_LIBS = initializeLibs();

    static boolean initializeLibs() {
        System.loadLibrary(SwiftKit.STDLIB_DYLIB_NAME);
        System.loadLibrary("SwiftKitSwift");
        return true;
    }



    // ==== ------------------------------------------------------------------------
    // count

    private static class count {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /* -> */SWIFT_INT,
                SWIFT_POINTER, // Array<Element>
                SWIFT_POINTER // metadata pointer: Element
        );
        public static final MemorySegment ADDR =
                SwiftKit.findOrThrow("swiftjava_SwiftKitSwift_Array_count");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }


    public int count() {
        var mh$ = count.HANDLE;
        try {
            if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall(self$);
            }
            // A Swift array has `Int` length which is a Java long potentially,
            // however it won't be so large so we will to-int-convert it...
            var count = (long) mh$.invokeExact(
                    self$, // the array
                    wrappedType.$memorySegment() // the T metadata
            );

            System.out.println("got array count = " + count);

            return Math.toIntExact(count);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    // ==== ------------------------------------------------------------------------
    // get

    private static class get {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /* -> */SWIFT_POINTER,
                SWIFT_POINTER, // Array<Element>
                SWIFT_INT, // index: Int
                SWIFT_POINTER // metadata pointer: Element
        );
        public static final MemorySegment ADDR =
                SwiftKit.findOrThrow("swiftjava_SwiftKitSwift_Array_get");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }


    public Wrapped get(long index) {
        var mh$ = get.HANDLE;
        try {
            if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall(self$);
            }

            var pointer = (MemorySegment) mh$.invokeExact(
                    self$, // the array
                    index,
                    wrappedType.$memorySegment() // the T metadata
            );

            return this.wrapAsWrapped.apply(pointer);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public Wrapped getWithVarHandle(long index) {
        var mh$ = get.HANDLE;
        try {
            if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall(self$);
            }


            var pointer = (MemorySegment) mh$.invokeExact(
                    self$, // the array
                    index,
                    wrappedType.$memorySegment() // the T metadata
            );

            return this.wrapAsWrapped.apply(pointer);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    // ==== ------------------------------------------------------------------------
    // swap

    public Wrapped swap(int i, int j) {
        throw new RuntimeException("Not implemented");
    }
}
