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

import org.swift.swiftkit.core.ConfinedSwiftMemorySession;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;

final class FFMConfinedSwiftMemorySession extends ConfinedSwiftMemorySession implements AllocatingSwiftArena, ClosableAllocatingSwiftArena {
    final Arena arena;

    public FFMConfinedSwiftMemorySession() {
        super();
        this.arena = Arena.ofConfined();
    }

    @Override
    public void close() {
        super.close();
        this.arena.close();
    }

    @Override
    public MemorySegment allocate(long byteSize, long byteAlignment) {
        return arena.allocate(byteSize, byteAlignment);
    }
}
