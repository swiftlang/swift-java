//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.swiftkit.core;

/**
 * A mutable holder for a Swift instance's memory address.
 * <p>
 * A {@link SwiftInstance} and its {@link SwiftInstanceCleanup} share the same holder so the
 * cleanup can zero the address after destroy without capturing the Java wrapper itself.
 * That keeps the cleanup safe to register with a {@link java.lang.ref.Cleaner}.
 */
public final class SwiftInstancePointer {
    private volatile long address;

    public SwiftInstancePointer(long address) {
        this.address = address;
    }

    /**
     * The current memory address, or {@code 0} if this pointer has been cleared.
     */
    public long get() {
        return address;
    }

    /**
     * Zero the stored address so it can no longer be used to reach Swift memory.
     */
    public void clear() {
        this.address = 0L;
    }
}
