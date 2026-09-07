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

package org.swift.swiftkit.core;

/**
 * Corresponds to Swift's {@code UnsafeBufferPointer<T>}
 */
public final class SwiftUnsafeBufferPointer {
    /** Address of the first element, as a raw pointer bit pattern. */
    private long baseAddress;

    /** Number of elements in the buffer */
    private long count;

    public SwiftUnsafeBufferPointer() {
        this(0, 0);
    }

    /**
     * @param baseAddress address of the first element, as a raw pointer bit pattern
     * @param count number of elements in the buffer
     */
    public SwiftUnsafeBufferPointer(long baseAddress, long count) {
        this.baseAddress = baseAddress;
        this.count = count;
    }

    /**
     * @return address of the first element, as a raw pointer bit pattern
     */
    public long getBaseAddress() {
        return baseAddress;
    }

    /**
     * @return number of elements in the buffer
     */
    public long getCount() {
        return count;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof SwiftUnsafeBufferPointer)) return false;
        SwiftUnsafeBufferPointer o = (SwiftUnsafeBufferPointer) other;
        return this.baseAddress == o.baseAddress && this.count == o.count;
    }

    @Override
    public int hashCode() {
        return java.util.Objects.hash(baseAddress, count);
    }

    @Override
    public String toString() {
        return "SwiftUnsafeBufferPointer(baseAddress=0x" + Long.toHexString(baseAddress) + ", count=" + count + ")";
    }
}
