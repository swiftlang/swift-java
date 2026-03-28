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

import java.lang.foreign.MemorySegment;

/**
 * Represents a Swift error thrown across the FFM boundary.
 *
 * When a Swift function marked as 'throws' raises an error, the error is
 * wrapped in a SwiftJavaError on the Swift side and its opaque pointer is
 * stored in the error out-parameter. The Java wrapper checks this pointer
 * after the downcall and throws this exception if non-null.
 *
 * TODO: jextract will eventually generate a full SwiftJavaError with downcall
 * methods for errorDescription(), errorType(), etc.
 */
public class SwiftJavaError extends Exception {
    private final MemorySegment errorPointer;

    public SwiftJavaError(MemorySegment errorPointer, AllocatingSwiftArena arena) {
        super("Swift error (address: 0x" + Long.toHexString(errorPointer.address()) + ")");
        this.errorPointer = errorPointer;
    }

    public MemorySegment getErrorPointer() {
        return errorPointer;
    }
}
