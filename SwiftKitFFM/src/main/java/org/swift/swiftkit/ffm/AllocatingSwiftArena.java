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

package org.swift.swiftkit.ffm;

import org.swift.swiftkit.core.SwiftArena;

import java.lang.foreign.MemorySegment;
import java.util.concurrent.ThreadFactory;

public interface AllocatingSwiftArena extends SwiftArena {
    MemorySegment allocate(long byteSize, long byteAlignment);

    static ClosableAllocatingSwiftArena ofConfined() {
        return new FFMConfinedSwiftMemorySession(Thread.currentThread());
    }

    static AllocatingSwiftArena ofAuto() {
        ThreadFactory cleanerThreadFactory = r -> new Thread(r, "AutoSwiftArenaCleanerThread");
        return new AllocatingAutoSwiftMemorySession(cleanerThreadFactory);
    }
}
