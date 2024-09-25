//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.javakit;

import org.swift.swiftkit.SwiftHeapObject;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.util.Arrays;
import java.util.stream.Collectors;

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
                /*returns=*/ValueLayout.ADDRESS,
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
}
