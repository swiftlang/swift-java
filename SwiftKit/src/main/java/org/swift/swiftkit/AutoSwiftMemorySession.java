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

import java.lang.foreign.MemorySegment;
import java.lang.ref.Cleaner;
import java.util.Objects;
import java.util.concurrent.ThreadFactory;

/**
 * A memory session which manages registered objects via the Garbage Collector.
 *
 * <p> When registered Java wrapper classes around native Swift instances {@link SwiftInstance},
 * are eligible for collection, this will trigger the cleanup of the native resources as well.
 *
 * <p> This memory session is LESS reliable than using a {@link ConfinedSwiftMemorySession} because
 * the timing of when the native resources are cleaned up is somewhat undefined, and rely on the
 * system GC. Meaning, that if an object nas been promoted to an old generation, there may be a
 * long time between the resource no longer being referenced "in Java" and its native memory being released,
 * and also the deinit of the Swift type being run.
 *
 * <p> This can be problematic for Swift applications which rely on quick release of resources, and may expect
 * the deinits to run in expected and "quick" succession.
 *
 * <p> Whenever possible, prefer using an explicitly managed {@link SwiftArena}, such as {@link SwiftArena#ofConfined()}.
 */
final class AutoSwiftMemorySession implements SwiftArena {

    private final Cleaner cleaner;

    public AutoSwiftMemorySession(ThreadFactory cleanerThreadFactory) {
        this.cleaner = Cleaner.create(cleanerThreadFactory);
    }

    @Override
    public void register(SwiftHeapObject object) {
        SwiftHeapObjectCleanup cleanupAction = new SwiftHeapObjectCleanup(object.$memorySegment(), object.$swiftType());
        register(object, cleanupAction);
    }

    // visible for testing
    void register(SwiftHeapObject object, SwiftHeapObjectCleanup cleanupAction) {
        Objects.requireNonNull(object, "obj");
        Objects.requireNonNull(cleanupAction, "cleanupAction");


        cleaner.register(object, cleanupAction);
    }

    @Override
    public void register(SwiftValue value) {
        Objects.requireNonNull(value, "value");
        MemorySegment resource = value.$memorySegment();
        var cleanupAction = new SwiftValueCleanup(resource);
        cleaner.register(value, cleanupAction);
    }

}
