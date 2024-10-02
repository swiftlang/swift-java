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

import org.swift.javakit.SwiftKit;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.util.concurrent.ConcurrentSkipListSet;

public interface SwiftArena extends Arena {

    void release(MemorySegment segment);

    void retain(MemorySegment segment);

    long retainCount(MemorySegment segment);

}

final class AutoSwiftArena implements SwiftArena {
    Arena underlying;

    ConcurrentSkipListSet<MemorySegment> managedMemorySegments;

    @Override
    public MemorySegment allocate(long byteSize, long byteAlignment) {
        return null;
    }

    @Override
    public MemorySegment.Scope scope() {
        return null;
    }

    @Override
    public void close() {

    }

    @Override
    public void release(MemorySegment segment) {
        SwiftKit.release(segment);
    }

    @Override
    public void retain(MemorySegment segment) {
        SwiftKit.retain(segment);
    }

    @Override
    public long retainCount(MemorySegment segment) {
        return SwiftKit.retainCount(segment);
    }
}
