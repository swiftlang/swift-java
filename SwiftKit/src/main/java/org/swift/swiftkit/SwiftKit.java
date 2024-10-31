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

import org.swift.swiftkit.util.PlatformUtils;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.util.Arrays;
import java.util.Optional;
import java.util.stream.Collectors;

import static org.swift.swiftkit.util.StringUtils.stripPrefix;
import static org.swift.swiftkit.util.StringUtils.stripSuffix;

public class SwiftKit {

    public static final String STDLIB_DYLIB_NAME = "swiftCore";
    public static final String SWIFTKIT_DYLIB_NAME = "SwiftKitSwift";

    static final String STDLIB_MACOS_DYLIB_PATH = "/usr/lib/swift/libswiftCore.dylib";

    static final Arena LIBRARY_ARENA = Arena.ofAuto();
    static final boolean TRACE_DOWNCALLS = Boolean.getBoolean("jextract.trace.downcalls");

    static {
        System.loadLibrary(STDLIB_DYLIB_NAME);
        System.loadLibrary(SWIFTKIT_DYLIB_NAME);
    }

    static final SymbolLookup SYMBOL_LOOKUP = getSymbolLookup();

    private static SymbolLookup getSymbolLookup() {
        if (PlatformUtils.isMacOS()) {
            // On Apple platforms we need to lookup using the complete path
            return SymbolLookup.libraryLookup(STDLIB_MACOS_DYLIB_PATH, LIBRARY_ARENA)
                    .or(SymbolLookup.loaderLookup())
                    .or(Linker.nativeLinker().defaultLookup());
        } else {
            return SymbolLookup.loaderLookup()
                    .or(Linker.nativeLinker().defaultLookup());
        }
    }

    public SwiftKit() {
    }

    static void traceDowncall(String name, Object... args) {
        String traceArgs = Arrays.stream(args)
                .map(Object::toString)
                .collect(Collectors.joining(", "));
        System.out.printf("[java] Downcall: %s(%s)\n", name, traceArgs);
    }

    static MemorySegment findOrThrow(String symbol) {
        return SYMBOL_LOOKUP.find(symbol)
                .orElseThrow(() -> new UnsatisfiedLinkError("unresolved symbol: %s".formatted(symbol)));
    }

    public static String getJavaLibraryPath() {
        return System.getProperty("java.library.path");
    }

    public static boolean getJextractTraceDowncalls() {
        return Boolean.getBoolean("jextract.trace.downcalls");
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // free

    static abstract class free {
        /**
         * Descriptor for the free C runtime function.
         */
        public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
                ValueLayout.ADDRESS
        );

        /**
         * Address of the free C runtime function.
         */
        public static final MemorySegment ADDR = findOrThrow("free");

        /**
         * Handle for the free C runtime function.
         */
        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }

    /**
     * free the given pointer
     */
    public static void cFree(MemorySegment pointer) {
        try {
            free.HANDLE.invokeExact(pointer);
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
        return retainCount(object.$memorySegment());
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

    public static void retain(SwiftHeapObject object) {
        retain(object.$memorySegment());
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
                traceDowncall("swift_release", object);
            }
            mh$.invokeExact(object);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static long release(SwiftHeapObject object) {
        return retainCount(object.$memorySegment());
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // getTypeByName

    /**
     * {@snippet lang = swift:
     * func _typeByName(_: Swift.String) -> Any.Type?
     *}
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
                traceDowncall("_typeByName");
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
     * {@snippet lang = swift:
     * func _swift_getTypeByMangledNameInEnvironment(
     *     _ name: UnsafePointer<UInt8>,
     *     _ nameLength: UInt,
     *     genericEnvironment: UnsafeRawPointer?,
     *     genericArguments: UnsafeRawPointer?
     * ) -> Any.Type?
     *}
     */
    private static class swift_getTypeByMangledNameInEnvironment {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /*returns=*/SwiftValueLayout.SWIFT_POINTER,
                ValueLayout.ADDRESS,
                ValueLayout.JAVA_INT,
                ValueLayout.ADDRESS,
                ValueLayout.ADDRESS
        );

        public static final MemorySegment ADDR = findOrThrow("swift_getTypeByMangledNameInEnvironment");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }

    private static class getTypeByStringByteArray {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /*returns=*/SwiftValueLayout.SWIFT_POINTER,
                ValueLayout.ADDRESS
        );

        public static final MemorySegment ADDR = findOrThrow("getTypeByStringByteArray");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }

    /**
     * Get a Swift {@code Any.Type} wrapped by {@link SwiftAnyType} which represents the type metadata available at runtime.
     *
     * @param mangledName The mangled type name (often prefixed with {@code $s}).
     * @return the Swift Type wrapper object
     */
    public static Optional<SwiftAnyType> getTypeByMangledNameInEnvironment(String mangledName) {
        System.out.println("Get Any.Type for mangled name: " + mangledName);

        var mh$ = swift_getTypeByMangledNameInEnvironment.HANDLE;
        try {
            // Strip the generic "$s" prefix always
            mangledName = stripPrefix(mangledName, "$s");
            // Ma is the "metadata accessor" mangled names of types we get from swiftinterface
            // contain this, but we don't need it for type lookup
            mangledName = stripSuffix(mangledName, "Ma");
            mangledName = stripSuffix(mangledName, "CN");
            if (TRACE_DOWNCALLS) {
                traceDowncall("swift_getTypeByMangledNameInEnvironment", mangledName);
            }
            try (Arena arena = Arena.ofConfined()) {
                MemorySegment stringMemorySegment = arena.allocateFrom(mangledName);

                var memorySegment = (MemorySegment) mh$.invokeExact(stringMemorySegment, mangledName.length(), MemorySegment.NULL, MemorySegment.NULL);

                if (memorySegment.address() == 0) {
                    return Optional.empty();
                }

                var wrapper = new SwiftAnyType(memorySegment);
                return Optional.of(wrapper);
            }
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    /**
     * Read a Swift.Int value from memory at the given offset and translate it into a Java long.
     * <p>
     * This function copes with the fact that a Swift.Int might be 32 or 64 bits.
     */
    public static long getSwiftInt(MemorySegment memorySegment, long offset) {
        if (SwiftValueLayout.SWIFT_INT == ValueLayout.JAVA_LONG) {
            return memorySegment.get(ValueLayout.JAVA_LONG, offset);
        } else {
            return memorySegment.get(ValueLayout.JAVA_INT, offset);
        }
    }



    private static class swift_getTypeName {

        /**
         * Descriptor for the swift_getTypeName runtime function.
         */
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /*returns=*/MemoryLayout.structLayout(
                        SwiftValueLayout.SWIFT_POINTER.withName("utf8Chars"),
                        SwiftValueLayout.SWIFT_INT.withName("length")
                ),
                ValueLayout.ADDRESS,
                ValueLayout.JAVA_BOOLEAN
        );

        /**
         * Address of the swift_getTypeName runtime function.
         */
        public static final MemorySegment ADDR = findOrThrow("swift_getTypeName");

        /**
         * Handle for the swift_getTypeName runtime function.
         */
        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }

    /**
     * Produce the name of the Swift type given its Swift type metadata.
     * <p>
     * If 'qualified' is true, leave all the qualification in place to
     * disambiguate the type, producing a more complete (but longer) type name.
     *
     * @param typeMetadata the memory segment must point to a Swift metadata,
     *                     e.g. the result of a {@link swift_getTypeByMangledNameInEnvironment} call
     */
    public static String nameOfSwiftType(MemorySegment typeMetadata, boolean qualified) {
        MethodHandle mh = swift_getTypeName.HANDLE;

        try (Arena arena = Arena.ofConfined()) {
            MemorySegment charsAndLength = (MemorySegment) mh.invokeExact((SegmentAllocator) arena, typeMetadata, qualified);
            MemorySegment utf8Chars = charsAndLength.get(SwiftValueLayout.SWIFT_POINTER, 0);
            String typeName = utf8Chars.getString(0);

            // FIXME: this free is not always correct:
            //      java(80175,0x17008f000) malloc: *** error for object 0x600000362610: pointer being freed was not allocated
            // cFree(utf8Chars);

            return typeName;
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

}
