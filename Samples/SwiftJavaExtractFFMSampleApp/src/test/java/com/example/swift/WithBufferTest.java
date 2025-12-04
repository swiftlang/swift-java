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

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.IntStream;

public class WithBufferTest {

    public static byte[] returnArray() {
        try (var arena$ = Arena.ofConfined()) {
            MemorySegment _result_pointer = arena$.allocate(SwiftValueLayout.SWIFT_POINTER);
            MemorySegment _result_count = arena$.allocate(SwiftValueLayout.SWIFT_INT64);
            // swiftjava_SwiftModule_returnArray.call(_result_pointer, _result_count);
//            return _result_pointer
//                    .get(SwiftValueLayout.SWIFT_POINTER, 0)
//                    .reinterpret(_result_count.get(SwiftValueLayout.SWIFT_INT64, 0));
            MemorySegment memorySegment = _result_pointer
                    .get(SwiftValueLayout.SWIFT_POINTER, 0);
            long newSize = _result_count.get(SwiftValueLayout.SWIFT_INT64, 0);
            MemorySegment arraySegment = memorySegment.reinterpret(newSize);
            return arraySegment.toArray(ValueLayout.JAVA_BYTE);
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
