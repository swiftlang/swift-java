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

import java.lang.foreign.GroupLayout;
import java.lang.foreign.MemorySegment;
import java.util.concurrent.atomic.AtomicBoolean;

public interface SwiftInstance {

    /**
     * The pointer to the instance in memory. I.e. the {@code self} of the Swift object or value.
     */
    MemorySegment $memorySegment();

    /**
     * The in memory layout of an instance of this Swift type.
     */
    GroupLayout $layout();

    SwiftAnyType $swiftType();

    /**
     * Returns `true` if this swift instance is a reference type, i.e. a `class` or (`distributed`) `actor`.
     *
     * @return `true` if this instance is a reference type, `false` otherwise.
     */
    default boolean isReferenceType() {
        return this instanceof SwiftHeapObject;
    }

    /**
     * Exposes a boolean value which can be used to indicate if the object was destroyed.
     * <p/>
     * This is exposing the object, rather than performing the action because we don't want to accidentally
     * form a strong reference to the {@code SwiftInstance} which could prevent the cleanup from running,
     * if using an GC managed instance (e.g. using an {@link AutoSwiftMemorySession}.
     */
    AtomicBoolean $statusDestroyedFlag();
}
