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

package com.example.swift;

import org.swift.swiftkit.SwiftArrayRef;
import org.swift.swiftkit.SwiftKit;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.invoke.MethodHandle;

import static org.swift.swiftkit.SwiftValueLayout.SWIFT_POINTER;

public final class ManualImportedMethods {
    static final String LIB_NAME = "MySwiftLibrary";

    @SuppressWarnings("unused")
    private static final boolean INITIALIZED_LIBS = initializeLibs();
    static boolean initializeLibs() {
        System.loadLibrary(SwiftKit.STDLIB_DYLIB_NAME);
        System.loadLibrary("SwiftKitSwift");
        System.loadLibrary(LIB_NAME);
        return true;
    }

    private static class getArrayMySwiftClass {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /* -> */SWIFT_POINTER
        );
        public static final MemorySegment ADDR =
                SwiftKit.findOrThrow("swiftjava_manual_getArrayMySwiftClass");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }


    public static SwiftArrayRef<MySwiftClass> getArrayMySwiftClass() {
        MethodHandle mh = getArrayMySwiftClass.HANDLE;

        Arena arena = Arena.ofAuto();
        try {
            if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall();
            }

            MemorySegment arrayPointer = (MemorySegment) mh.invokeExact();
            return new SwiftArrayRef<>(
                    arena,
                    arrayPointer,
                    /* element type = */MySwiftClass.TYPE_METADATA
            );
        } catch (Throwable e) {
            throw new RuntimeException("Failed to invoke Swift method", e);
        }
    }
}
