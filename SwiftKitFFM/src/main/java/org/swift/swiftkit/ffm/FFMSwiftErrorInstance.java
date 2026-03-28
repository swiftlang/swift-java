//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.swiftkit.ffm;

import org.swift.swiftkit.core.SwiftInstance;
import org.swift.swiftkit.core.SwiftInstanceCleanup;

import java.lang.foreign.MemorySegment;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Base class for Swift errors passed across the FFM boundary.
 * Extends {@link Exception} so it can be thrown in Java, and implements
 * {@link SwiftInstance} for proper lifecycle management.
 */
public abstract class FFMSwiftErrorInstance extends Exception implements SwiftInstance {
    private final MemorySegment memorySegment;
    private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);

    protected FFMSwiftErrorInstance(String message, MemorySegment segment, AllocatingSwiftArena arena) {
        super(message);
        this.memorySegment = segment;
        arena.register(this);
    }

    protected FFMSwiftErrorInstance(MemorySegment segment, AllocatingSwiftArena arena) {
        super();
        this.memorySegment = segment;
        arena.register(this);
    }

    public final MemorySegment $memorySegment() {
        return memorySegment;
    }

    @Override
    public long $memoryAddress() {
        return $memorySegment().address();
    }

    public final AtomicBoolean $statusDestroyedFlag() {
        return $state$destroyed;
    }

    /**
     * The Swift type metadata of this type.
     */
    public abstract SwiftAnyType $swiftType();

    @Override
    public SwiftInstanceCleanup $createCleanup() {
        var statusDestroyedFlag = $statusDestroyedFlag();
        Runnable markAsDestroyed = () -> statusDestroyedFlag.set(true);

        return new FFMSwiftInstanceCleanup(
                $memorySegment(),
                $swiftType(),
                markAsDestroyed
        );
    }
}
