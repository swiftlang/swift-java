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

public interface SwiftMemoryResource {

    /**
     * The pointer to the instance in memory. I.e. the {@code self} of the Swift object or value.
     */
    MemorySegment $memorySegment();

    /** The in memory layout of an instance of this Swift type. */
    GroupLayout $layout();

    default boolean immortal() {
        return false;
    }
}
