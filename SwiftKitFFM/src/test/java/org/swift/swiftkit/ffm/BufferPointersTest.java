//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.swiftkit.ffm;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.SwiftUnsafeBufferPointer;
import org.swift.swiftkit.core.SwiftUnsafeMutableBufferPointer;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.nio.ReadOnlyBufferException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class BufferPointersTest {

    @Test
    public void toByteBuffer_viewsUnderlyingInt32Elements() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment native_ = arena.allocate(SwiftValueLayout.SWIFT_INT32, 3);
            native_.setAtIndex(SwiftValueLayout.SWIFT_INT32, 0, 10);
            native_.setAtIndex(SwiftValueLayout.SWIFT_INT32, 1, 20);
            native_.setAtIndex(SwiftValueLayout.SWIFT_INT32, 2, 30);

            var buffer = new SwiftUnsafeBufferPointer(native_.address(), 3);

            ByteBuffer byteBuffer = BufferPointers.toByteBuffer(buffer, SwiftValueLayout.SWIFT_INT32);
            byteBuffer.order(java.nio.ByteOrder.nativeOrder());

            assertEquals(12, byteBuffer.capacity());
            assertEquals(10, byteBuffer.asIntBuffer().get(0));
            assertEquals(20, byteBuffer.asIntBuffer().get(1));
            assertEquals(30, byteBuffer.asIntBuffer().get(2));
        }
    }

    @Test
    public void toByteBuffer_emptyBuffer_isEmpty() {
        var buffer = new SwiftUnsafeBufferPointer(0, 0);
        ByteBuffer byteBuffer = BufferPointers.toByteBuffer(buffer, SwiftValueLayout.SWIFT_INT32);
        assertEquals(0, byteBuffer.capacity());
    }

    @Test
    public void toByteBuffer_mutableBuffer_isWritableThrough() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment native_ = arena.allocate(SwiftValueLayout.SWIFT_INT8, 4);

            var buffer = new SwiftUnsafeMutableBufferPointer(native_.address(), 4);
            ByteBuffer byteBuffer = BufferPointers.toByteBuffer(buffer, SwiftValueLayout.SWIFT_INT8);
            byteBuffer.put(0, (byte) 42);

            assertEquals(42, native_.get(SwiftValueLayout.SWIFT_INT8, 0));
        }
    }

    @Test
    public void toByteBuffer_immutableBuffer_throwsOnWriteAttempt() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment native_ = arena.allocate(SwiftValueLayout.SWIFT_INT32, 2);
            var buffer = new SwiftUnsafeBufferPointer(native_.address(), 2);

            ByteBuffer byteBuffer = BufferPointers.toByteBuffer(buffer, SwiftValueLayout.SWIFT_INT32);

            assertTrue(byteBuffer.isReadOnly());
            assertThrows(ReadOnlyBufferException.class, () -> byteBuffer.put(0, (byte) 1));
        }
    }

    @Test
    public void toByteBuffer_immutableBuffer_subViewsAreAlsoReadOnly() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment native_ = arena.allocate(SwiftValueLayout.SWIFT_INT32, 2);
            var buffer = new SwiftUnsafeBufferPointer(native_.address(), 2);

            ByteBuffer byteBuffer = BufferPointers.toByteBuffer(buffer, SwiftValueLayout.SWIFT_INT32);
            IntBuffer intBuffer = byteBuffer.asIntBuffer();

            assertTrue(intBuffer.isReadOnly());
            assertThrows(ReadOnlyBufferException.class, () -> intBuffer.put(0, 100));
        }
    }
}
