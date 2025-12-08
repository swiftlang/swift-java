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

import java.lang.foreign.ValueLayout;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.IntStream;

import com.example.swift.MySwiftLibrary.*;

public class WithBufferTest {
    @Test
    void test_withBuffer() {
        AtomicLong bufferSize = new AtomicLong();
        MySwiftLibrary.withBuffer((buf) -> {
            CallTraces.trace("withBuffer{$0.byteSize()}=" + buf.byteSize());
            bufferSize.set(buf.byteSize());
        });

        assertEquals(124, bufferSize.get());
    }

    @Test
    void test_sumAllByteArrayElements_throughMemorySegment() {
        byte[] bytes =  new byte[124];
        Arrays.fill(bytes, (byte) 1);

        try (var arena = AllocatingSwiftArena.ofConfined()) {
            // NOTE: We cannot use MemorySegment.ofArray because that creates a HEAP backed segment and therefore cannot pass into native:
            //         java.lang.IllegalArgumentException: Heap segment not allowed: MemorySegment{ kind: heap, heapBase: [B@5b6ec132, address: 0x0, byteSize: 124 }
            //            MemorySegment bytesSegment = MemorySegment.ofArray(bytes); // NO COPY (!)
            //            MySwiftLibrary.sumAllByteArrayElements(bytesSegment, bytes.length);

            var bytesCopy = arena.allocateFrom(ValueLayout.JAVA_BYTE, bytes);
            var swiftSideSum = MySwiftLibrary.sumAllByteArrayElements(bytesCopy, bytes.length);

            System.out.println("swiftSideSum = " + swiftSideSum);

            int javaSideSum = IntStream.range(0, bytes.length).map(i -> bytes[i]).sum();
            assertEquals(javaSideSum, swiftSideSum);
        }
    }
}
