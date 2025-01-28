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

import java.lang.foreign.SegmentAllocator;
import java.util.concurrent.ThreadFactory;

/**
 * A Swift arena manages Swift allocated memory for classes, structs, enums etc.
 * When an arena is closed, it will destroy all managed swift objects in a way appropriate to their type.
 *
 * <p> A confined arena has an associated owner thread that confines some operations to
 * associated owner thread such as {@link ClosableSwiftArena#close()}.
 */
public interface SwiftArena extends SegmentAllocator {

    static ClosableSwiftArena ofConfined() {
        return new ConfinedSwiftMemorySession(Thread.currentThread());
    }

    static SwiftArena ofAuto() {
        ThreadFactory cleanerThreadFactory = r -> new Thread(r, "AutoSwiftArenaCleanerThread");
        return new AutoSwiftMemorySession(cleanerThreadFactory);
    }

    /**
     * Register a Swift reference counted heap object with this arena (such as a {@code class} or {@code actor}).
     * Its memory should be considered managed by this arena, and be destroyed when the arena is closed.
     */
    void register(SwiftHeapObject object);

    /**
     * Register a struct, enum or other non-reference counted Swift object.
     * Its memory should be considered managed by this arena, and be destroyed when the arena is closed.
     */
    void register(SwiftValue value);

}

/**
 * Represents a list of resources that need a cleanup, e.g. allocated classes/structs.
 */
interface SwiftResourceList {

    void runCleanup();

}


final class UnexpectedRetainCountException extends RuntimeException {
    public UnexpectedRetainCountException(Object resource, long retainCount, int expectedRetainCount) {
        super(("Attempting to cleanup managed memory segment %s, but it's retain count was different than [%d] (was %d)! " +
                "This would result in destroying a swift object that is still retained by other code somewhere."
        ).formatted(resource, expectedRetainCount, retainCount));
    }
}
