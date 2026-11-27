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
 * A mutable holder for an FFM Swift instance's {@link MemorySegment}.
 * <p>
 * Shared by the Java wrapper and its cleanup so the segment can be cleared after
 * destroy without the cleanup capturing the wrapper itself.
 */
final class FFMInstanceMemory {
    private volatile MemorySegment segment;

    FFMInstanceMemory(MemorySegment segment) {
        this.segment = segment;
    }

    MemorySegment get() {
        return segment;
    }

    void clear() {
        this.segment = null;
    }
}
