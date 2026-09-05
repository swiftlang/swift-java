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

import org.swift.swiftkit.core.SwiftUnsafeBufferPointer;
import org.swift.swiftkit.core.SwiftUnsafeMutableBufferPointer;

import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.ByteBuffer;

/**
 * Conversions between {@code SwiftUnsafe(Mutable)BufferPointer} and the Java Foreign Function
 * &amp; Memory API.
 * <p>
 * These types are zero-copy views: the {@code baseAddress} they carry is already a valid pointer
 * into the current process' address space, so no data needs to be copied out of Swift to access
 * it from Java.
 */
public class BufferPointers {

    /**
     * Reinterprets the given buffer's {@code baseAddress} as a {@link MemorySegment} covering
     * exactly {@code count * elementLayout.byteSize()} bytes.
     *
     * <p> the returned segment is valid for only as long as that memory is.
     *
     * @param buffer        the buffer pointer to view
     * @param elementLayout the layout of the buffer's element type, e.g. {@link SwiftValueLayout#SWIFT_INT32}
     * @return a zero-copy {@link MemorySegment} view of the buffer's contents
     */
    private static MemorySegment toMemorySegment(SwiftUnsafeBufferPointer buffer, ValueLayout elementLayout) {
        long byteSize = buffer.getCount() * elementLayout.byteSize();
        if (byteSize == 0) {
            return MemorySegment.NULL;
        }
        return MemorySegment.ofAddress(buffer.getBaseAddress()).reinterpret(byteSize);
    }

    /**
     * Reinterprets the given mutable buffer's {@code baseAddress} as a {@link MemorySegment}
     * covering exactly {@code count * elementLayout.byteSize()} bytes.
     *
     * <p> the returned segment is valid for only as long as that memory is.
     * 
     * @param buffer        the buffer pointer to view
     * @param elementLayout the layout of the buffer's element type, e.g. {@link SwiftValueLayout#SWIFT_INT32}
     * @return a zero-copy {@link MemorySegment} view of the buffer's contents
     */
    private static MemorySegment toMemorySegment(SwiftUnsafeMutableBufferPointer buffer, ValueLayout elementLayout) {
        long byteSize = buffer.getCount() * elementLayout.byteSize();
        if (byteSize == 0) {
            return MemorySegment.NULL;
        }
        return MemorySegment.ofAddress(buffer.getBaseAddress()).reinterpret(byteSize);
    }

    /**
     * A {@link ByteBuffer} view of the given buffer's contents, backed by the same native memory.
     *
     * @param buffer        the buffer pointer to view
     * @param elementLayout the layout of the buffer's element type, e.g. {@link SwiftValueLayout#SWIFT_INT32}
     * @return a zero-copy {@link ByteBuffer} view of the buffer's contents
     */
    public static ByteBuffer toByteBuffer(SwiftUnsafeBufferPointer buffer, ValueLayout elementLayout) {
        MemorySegment segment = toMemorySegment(buffer, elementLayout);
        return segment == MemorySegment.NULL ? ByteBuffer.allocateDirect(0).asReadOnlyBuffer() : segment.asReadOnly().asByteBuffer();
    }

    /**
     * A {@link ByteBuffer} view of the given mutable buffer's contents, backed by the same native memory.
     *
     * @param buffer        the buffer pointer to view
     * @param elementLayout the layout of the buffer's element type, e.g. {@link SwiftValueLayout#SWIFT_INT32}
     * @return a zero-copy {@link ByteBuffer} view of the buffer's contents
     */
    public static ByteBuffer toByteBuffer(SwiftUnsafeMutableBufferPointer buffer, ValueLayout elementLayout) {
        MemorySegment segment = toMemorySegment(buffer, elementLayout);
        return segment == MemorySegment.NULL ? ByteBuffer.allocateDirect(0) : segment.asByteBuffer();
    }
}
