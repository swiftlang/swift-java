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
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import java.lang.foreign.ValueLayout;
import java.nio.ByteBuffer;

import static org.junit.jupiter.api.Assertions.*;

public class DataImportTest {
    @Test
    void data_echo() {
        // snippet.dataUsageJava
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] bytes = new byte[] { 1, 2, 3, 4 };
            var data = Data.fromByteArray(bytes, arena);

            var echoed = MySwiftLibrary.echoData(data, arena);
            assertArrayEquals(bytes, echoed.toByteArray());
        }
        // snippet.end
    }

    @Test
    void data_withUnsafeBytes() {
        // snippet.withUnsafeBytesUsageJava
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] bytes = new byte[] { 1, 2, 3, 4 };
            var data = Data.fromByteArray(bytes, arena);

            var echoed = MySwiftLibrary.echoData(data, arena);
            echoed.withUnsafeBytes((segment) -> {
                assertEquals(4, segment.byteSize());
                assertEquals(1, segment.get(ValueLayout.JAVA_BYTE, 0));
            });
        }
        // snippet.end
    }

    @Test
    void test_Data_receiveAndReturn() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var origBytes = arena.allocateFrom("foobar");
            var origDat = Data.init(origBytes, origBytes.byteSize(), arena);
            assertEquals(7, origDat.getCount());

            var retDat = MySwiftLibrary.globalReceiveReturnData(origDat, arena);
            assertEquals(7, retDat.getCount());
            retDat.withUnsafeBytes((retBytes) -> {
                assertEquals(7, retBytes.byteSize());
                var str = retBytes.getString(0);
                assertEquals("foobar", str);
            });
        }
    }

    @Test
    void test_DataProtocol_receive() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var bytes = arena.allocateFrom("hello");
            var dat = Data.init(bytes, bytes.byteSize(), arena);
            var result = MySwiftLibrary.globalReceiveSomeDataProtocol(dat);
            assertEquals(6, result);
        }
    }

    @Test
    void test_Data_toByteArray() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[] { 10, 20, 30, 40 };
            var data = Data.fromByteArray(original, arena);
            byte[] result = data.toByteArray();
            assertEquals(original.length, result.length);
            assertArrayEquals(original, result);
        }
    }

    @Test
    void test_Data_toByteArray_withArena() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[] { 10, 20, 30, 40 };
            var data = Data.fromByteArray(original, arena);
            byte[] result = data.toByteArray(arena);
            assertEquals(original.length, result.length);
            assertArrayEquals(original, result);
        }
    }

    @Test
    void test_Data_toByteArray_emptyData() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[0];
            var data = Data.fromByteArray(original, arena);
            byte[] result = data.toByteArray();
            assertEquals(0, result.length);
        }
    }

    @Test
    void test_Data_fromByteArray() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[] { 1, 2, 3, 4, 5 };
            var data = Data.fromByteArray(original, arena);
            assertEquals(5, data.getCount());
        }
    }

    @Test
    void test_Data_fromByteBuffer() {
        // snippet.byteBufferUsageJava
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[] { 1, 2, 3, 4, 5 };
            ByteBuffer buffer = ByteBuffer.wrap(original);
            var data = Data.fromByteBuffer(buffer, arena);
            assertEquals(5, data.getCount());
        }
        // snippet.end
    }

    @Test
    void test_Data_toMemorySegment() {
        // snippet.memorySegmentUsageJava
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[] { 10, 20, 30, 40 };
            var data = Data.fromByteArray(original, arena);
            var segment = data.toMemorySegment(arena);

            assertEquals(original.length, segment.byteSize());
            for (int i = 0; i < original.length; i++) {
                assertEquals(original[i], segment.get(ValueLayout.JAVA_BYTE, i));
            }
        }
        // snippet.end
    }

    @Test
    void test_Data_toByteBuffer() {
        // snippet.byteBufferToUsageJava
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[] { 10, 20, 30, 40 };
            var data = Data.fromByteArray(original, arena);
            var buffer = data.toByteBuffer(arena);

            assertEquals(original.length, buffer.capacity());
            for (int i = 0; i < original.length; i++) {
                assertEquals(original[i], buffer.get(i));
            }
        }
        // snippet.end
    }

    @Test
    void test_Data_toMemorySegment_emptyData() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[0];
            var data = Data.fromByteArray(original, arena);
            var segment = data.toMemorySegment(arena);
            assertEquals(0, segment.byteSize());
        }
    }

    @Test
    void test_Data_toByteBuffer_emptyData() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            byte[] original = new byte[0];
            var data = Data.fromByteArray(original, arena);
            var buffer = data.toByteBuffer(arena);
            
            assertEquals(0, buffer.capacity());
        }
    }

}
