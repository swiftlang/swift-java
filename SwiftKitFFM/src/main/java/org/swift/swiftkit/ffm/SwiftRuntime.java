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

package org.swift.swiftkit.ffm;

import org.swift.swiftkit.core.SwiftInstance;
import org.swift.swiftkit.core.CallTraces;
import org.swift.swiftkit.core.util.PlatformUtils;
import org.swift.swiftkit.ffm.SwiftRuntime.swiftjava;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;
import java.util.*;
import java.util.stream.Collectors;

import static org.swift.swiftkit.core.CallTraces.traceDowncall;
import static org.swift.swiftkit.core.util.StringUtils.stripPrefix;
import static org.swift.swiftkit.core.util.StringUtils.stripSuffix;

public class SwiftRuntime {

    public static final String STDLIB_DYLIB_NAME = "swiftCore";
    public static final String SWIFT_RUNTIME_FUNCTIONS_DYLIB_NAME = "SwiftRuntimeFunctions";

    private static final String STDLIB_MACOS_DYLIB_PATH = "/usr/lib/swift/libswiftCore.dylib";

    private static final Arena LIBRARY_ARENA = Arena.ofAuto();

    @SuppressWarnings("unused")
    private static final boolean INITIALIZED_LIBS = loadLibraries(false);

    public static boolean loadLibraries(boolean loadSwiftRuntimeFunctions) {
        try {
            System.loadLibrary(STDLIB_DYLIB_NAME);
            if (loadSwiftRuntimeFunctions) {
                System.loadLibrary(SWIFT_RUNTIME_FUNCTIONS_DYLIB_NAME);
            }
            return true;
        } catch (UnsatisfiedLinkError e) {
            // Libraries not on path - will be loaded later from JAR or other location
            if (CallTraces.TRACE_DOWNCALLS) {
                System.err.println("[swift-java] SwiftRuntime: Could not auto-load libraries from java.library.path: " + e.getMessage());
                System.err.println("[swift-java] Libraries will need to be loaded explicitly or from JAR resources");
            }
            return false;
        }
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

    public SwiftRuntime() {
    }

    static MemorySegment findOrThrow(String symbol) {
        return SYMBOL_LOOKUP.find(symbol)
                .orElseThrow(() -> new UnsatisfiedLinkError("unresolved symbol: %s".formatted(symbol)));
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
            if (CallTraces.TRACE_DOWNCALLS) {
                traceDowncall("swift_retainCount", object);
            }
            return (long) mh$.invokeExact(object);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static long retainCount(SwiftHeapObject object) {
        return retainCount(object.$instance());
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
            if (CallTraces.TRACE_DOWNCALLS) {
                traceDowncall("swift_retain", object);
            }
            mh$.invokeExact(object);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static void retain(SwiftHeapObject object) {
        retain(object.$instance());
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
            if (CallTraces.TRACE_DOWNCALLS) {
                traceDowncall("swift_release", object);
            }
            mh$.invokeExact(object);
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }

    public static void release(SwiftHeapObject object) {
        release(object.$instance());
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
            if (CallTraces.TRACE_DOWNCALLS) {
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
            if (CallTraces.TRACE_DOWNCALLS) {
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

    /***
     * Namespace for calls down into swift-java generated thunks and accessors, such as {@code swiftjava_getType_...} etc.
     * <p> Not intended to be used by end-user code directly, but used by swift-java generated Java code.
     */
    @SuppressWarnings("unused") // used by source generated Java code
    public static final class swiftjava {
        private swiftjava() { /* just a namespace */ }

        private static class getType {
            public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                    /* -> */ValueLayout.ADDRESS);
        }

        public static MemorySegment getType(String moduleName, String nominalName) {
            // We cannot cache this statically since it depends on the type names we're looking up
            // TODO: we could cache the handles per type once we have them, to speed up subsequent calls
            String symbol = "swiftjava_getType_" + moduleName + "_" + nominalName;

            try {
                var addr = findOrThrow(symbol);
                var mh$ = Linker.nativeLinker().downcallHandle(addr, getType.DESC);
                return (MemorySegment) mh$.invokeExact();
            } catch (Throwable e) {
                throw new AssertionError("Failed to call: " + symbol, e);
            }
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // Get Swift values out of native memory segments

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

    public static long getSwiftInt(MemorySegment memorySegment, VarHandle handle) {
        if (SwiftValueLayout.SWIFT_INT == ValueLayout.JAVA_LONG) {
            return (long) handle.get(memorySegment, 0);
        } else {
            return (int) handle.get(memorySegment, 0);
        }
    }

    /**
     * Get the method handle of a functional interface.
     *
     * @param fi functional interface.
     * @param name name of the single abstraction method.
     * @param fdesc function descriptor of the method.
     * @return unbound method handle.
     */
    public static MethodHandle upcallHandle(Class<?> fi, String name, FunctionDescriptor fdesc) {
        try {
            return MethodHandles.lookup().findVirtual(fi, name, fdesc.toMethodType());
        } catch (ReflectiveOperationException ex) {
            throw new AssertionError(ex);
        }
    }

    /**
     * Convert String to a MemorySegment filled with the C string.
     */
    public static MemorySegment toCString(String str, Arena arena) {
        return arena.allocateFrom(str);
    }

    public static MemorySegment toOptionalSegmentInt(OptionalInt opt, Arena arena) {
        return opt.isPresent() ? arena.allocateFrom(ValueLayout.JAVA_INT, opt.getAsInt()) : MemorySegment.NULL;
    }

    public static MemorySegment toOptionalSegmentLong(OptionalLong opt, Arena arena) {
        return opt.isPresent() ? arena.allocateFrom(ValueLayout.JAVA_LONG, opt.getAsLong()) : MemorySegment.NULL;
    }

    public static MemorySegment toOptionalSegmentDouble(OptionalDouble opt, Arena arena) {
        return opt.isPresent() ? arena.allocateFrom(ValueLayout.JAVA_DOUBLE, opt.getAsDouble()) : MemorySegment.NULL;
    }

    public static MemorySegment toOptionalSegmentBoolean(Optional<Boolean> opt, Arena arena) {
        return opt.map(val -> arena.allocateFrom(ValueLayout.JAVA_BYTE, (byte) (val ? 1 : 0))).orElse(MemorySegment.NULL);
    }

    public static MemorySegment toOptionalSegmentByte(Optional<Byte> opt, Arena arena) {
        return opt.map(val -> arena.allocateFrom(ValueLayout.JAVA_BYTE, val)).orElse(MemorySegment.NULL);
    }

    public static MemorySegment toOptionalSegmentCharacter(Optional<Character> opt, Arena arena) {
        return opt.map(val -> arena.allocateFrom(ValueLayout.JAVA_CHAR, val)).orElse(MemorySegment.NULL);
    }

    public static MemorySegment toOptionalSegmentShort(Optional<Short> opt, Arena arena) {
        return opt.map(val -> arena.allocateFrom(ValueLayout.JAVA_SHORT, val)).orElse(MemorySegment.NULL);
    }

    public static MemorySegment toOptionalSegmentFloat(Optional<Float> opt, Arena arena) {
        return opt.map(val -> arena.allocateFrom(ValueLayout.JAVA_FLOAT, val)).orElse(MemorySegment.NULL);
    }

    public static <Instance extends FFMSwiftInstance> MemorySegment toOptionalSegmentInstance(Optional<Instance> opt) {
        return opt.map(instance -> instance.$memorySegment()).orElse(MemorySegment.NULL);
    }

    private static class swift_getTypeName {

        /**
         * Descriptor for the swift_getTypeName runtime function.
         */
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /* -> */MemoryLayout.structLayout(
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

    public static void log(SwiftJavaLogGroup group, String message) {
        if (group.isEnabled()) {
            System.err.println(message);
        }
    }
    
    public static void log(SwiftJavaLogGroup group, String format, String ...args) {
        if (group.isEnabled()) {
            System.err.println(String.format(format, (Object[]) args));
        }
    }

}

enum SwiftJavaLogGroup {
    LIFECYCLE;

    static boolean LOG_LIFECYCLE = 
        Boolean.getBoolean("swift-java.log.lifecycle");

    boolean isEnabled() {
        switch (this) {
            case LIFECYCLE: return LOG_LIFECYCLE;
        }
        throw new IllegalArgumentException("Not handled log group: " + this);
    }
}
