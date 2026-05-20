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

/**
 * A Swift memory instance cleanup, e.g. count-down a reference count and destroy a class, or destroy struct/enum etc.
 * <p>
 * Implementations also serve as the destroyed-state holder for their associated {@link SwiftInstance},
 * exposing {@link #isDestroyed()} which can be polled even after the instance has been GC-ed.
 */
public interface SwiftInstanceCleanup extends Runnable {
    /**
     * Whether this cleanup has run, i.e. the associated instance has been destroyed.
     */
    boolean isDestroyed();
}
