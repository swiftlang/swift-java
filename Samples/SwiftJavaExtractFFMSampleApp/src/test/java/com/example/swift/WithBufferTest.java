//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package com.example.swift;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.*;
import org.swift.swiftkit.ffm.*;

import static org.junit.jupiter.api.Assertions.*;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.IntStream;

public class WithBufferTest {

    /**
     * {@snippet lang = c:
     * void swiftjava_SwiftModule_returnArray(void (*_result_initialize)(const void *, ptrdiff_t))
     *}
     */
    private static class swiftjava_SwiftModule_returnArray {
        private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
                /* _result_initialize: */SwiftValueLayout.SWIFT_POINTER
        );
        private static final MemorySegment ADDR = null;
        // SwiftModule.findOrThrow("swiftjava_SwiftModule_returnArray");
        private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);

        public static void call(java.lang.foreign.MemorySegment _result_initialize) {
            try {
                if (CallTraces.TRACE_DOWNCALLS) {
                    CallTraces.traceDowncall(_result_initialize);
                }
                HANDLE.invokeExact(_result_initialize);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }

        /**
         * {snippet lang=c :
         * void (*)(const void *, ptrdiff_t)
         * }
         */
        private static class $_result_initialize {
            public static final class Function {
                byte[] result = null;

                void apply(java.lang.foreign.MemorySegment _0, long _1) {
                    this.result = _0.reinterpret(_1).toArray(ValueLayout.JAVA_BYTE);
                }
            }

            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
                    /* _0: */SwiftValueLayout.SWIFT_POINTER,
                    /* _1: */SwiftValueLayout.SWIFT_INT
            );
            private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);

            private static MemorySegment toUpcallStub(Function fi, Arena arena) {
                return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
            }
        }
    }


}

@Test
void test_withBuffer() {
    AtomicLong bufferSize = new AtomicLong();
    MySwiftLibrary.withBuffer((buf) -> {
        CallTraces.trace("withBuffer{$0.byteSize()}=" + buf.byteSize());
        bufferSize.set(buf.byteSize());
    });

    assertEquals(124, bufferSize.get());
}
}
