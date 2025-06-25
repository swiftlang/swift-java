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

import java.lang.foreign.AddressLayout;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.SequenceLayout;
import java.lang.foreign.ValueLayout;

import static java.lang.foreign.ValueLayout.*;

/**
 * Similar to {@link java.lang.foreign.ValueLayout} however with some Swift specifics.
 */
public class SwiftValueLayout {

    /**
     * The width of a pointer on the current platform.
     */
    public static long addressByteSize() {
        return ValueLayout.ADDRESS.byteSize();
    }

    public static final ValueLayout.OfBoolean SWIFT_BOOL = ValueLayout.JAVA_BOOLEAN;
    public static final ValueLayout.OfByte SWIFT_INT8 = ValueLayout.JAVA_BYTE;
    public static final ValueLayout.OfChar SWIFT_UINT16 = ValueLayout.JAVA_CHAR;
    public static final ValueLayout.OfShort SWIFT_INT16 = ValueLayout.JAVA_SHORT;
    public static final ValueLayout.OfInt SWIFT_INT32 = ValueLayout.JAVA_INT;
    public static final ValueLayout.OfLong SWIFT_INT64 = ValueLayout.JAVA_LONG;
    public static final ValueLayout.OfFloat SWIFT_FLOAT = ValueLayout.JAVA_FLOAT;
    public static final ValueLayout.OfDouble SWIFT_DOUBLE = ValueLayout.JAVA_DOUBLE;

    // FIXME: this sequence layout is a workaround, we must properly size pointers when we get them.
    public static final AddressLayout SWIFT_POINTER = ValueLayout.ADDRESS
           .withTargetLayout(MemoryLayout.sequenceLayout(Long.MAX_VALUE, JAVA_BYTE));
    public static final SequenceLayout SWIFT_BYTE_ARRAY = MemoryLayout.sequenceLayout(8, ValueLayout.JAVA_BYTE);

    /**
     * The value layout for Swift's {@code Int} type, which is a signed type that follows
     * the size of a pointer (aka C's {@code ptrdiff_t}).
     */
    public static ValueLayout SWIFT_INT = (ValueLayout.ADDRESS.byteSize() == 4) ?
            SWIFT_INT32 : SWIFT_INT64;

    /**
     * The value layout for Swift's {@code UInt} type, which is an unsigned type that follows
     * the size of a pointer (aka C's {@code size_t}).
     * <p/>
     * Java does not have unsigned integer types, so we use the layout for Swift's {@code Int}.
     */
    public static ValueLayout SWIFT_UINT = SWIFT_INT;
}
