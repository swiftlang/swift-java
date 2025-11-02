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

package org.swift.swiftkit.core;

import java.util.concurrent.ThreadFactory;

/**
 * A Swift arena manages Swift allocated memory for classes, structs, enums etc.
 * When an arena is closed, it will destroy all managed swift objects in a way appropriate to their type.
 *
 * <p> A confined arena has an associated owner thread that confines some operations to
 * associated owner thread such as {@link ClosableSwiftArena#close()}.
 */
public interface SwiftArena {
    /**
     * Register a Swift object.
     * Its memory should be considered managed by this arena, and be destroyed when the arena is closed.
     */
    void register(SwiftInstance instance);

    static ClosableSwiftArena ofConfined() {
        return new ConfinedSwiftMemorySession();
    }

    static SwiftArena ofAuto() {
        ThreadFactory cleanerThreadFactory = r -> new Thread(r, "AutoSwiftArenaCleanerThread");
        return new AutoSwiftMemorySession(cleanerThreadFactory);
    }
}

/**
 * Represents a list of resources that need a cleanup, e.g. allocated classes/structs.
 */
interface SwiftResourceList {
    void runCleanup();
}
