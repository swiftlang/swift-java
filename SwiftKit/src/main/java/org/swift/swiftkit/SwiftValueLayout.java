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
import java.lang.foreign.ValueLayout;

import static java.lang.foreign.ValueLayout.JAVA_BYTE;

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

    public static final AddressLayout SWIFT_POINTER = ValueLayout.ADDRESS
            .withTargetLayout(MemoryLayout.sequenceLayout(Long.MAX_VALUE, JAVA_BYTE));

    /**
     * The value layout for Swift's {@code Int} type, which is a signed type that follows
     * the size of a pointer (aka C's {@code ptrdiff_t}).
     */
    public static ValueLayout SWIFT_INT = (ValueLayout.ADDRESS.byteSize() == 4) ?
            ValueLayout.JAVA_INT : ValueLayout.JAVA_LONG;


    /**
     * The value layout for Swift's {@code UInt} type, which is an unsigned type that follows
     * the size of a pointer (aka C's {@code size_t}).
     * <p/>
     * Java does not have unsigned integer types, so we use the layout for Swift's {@code Int}.
     */
    public static ValueLayout SWIFT_UINT = SWIFT_INT;


}
