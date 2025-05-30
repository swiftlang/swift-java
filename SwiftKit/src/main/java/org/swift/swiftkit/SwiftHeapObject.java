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

/**
 * Represents a wrapper around a Swift heap object, e.g. a {@code class} or an {@code actor}.
 */
public interface SwiftHeapObject {
    MemorySegment $memorySegment();

    /**
     * Pointer to the instance.
     */
    public default MemorySegment $instance() {
        return this.$memorySegment().get(SwiftValueLayout.SWIFT_POINTER, 0);
    }
}
