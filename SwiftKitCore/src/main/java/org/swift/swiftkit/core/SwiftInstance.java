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

public interface SwiftInstance {
    /**
     * Pointer to the {@code self} of the underlying Swift object or value.
     *
     * <p>Throws {@link IllegalStateException} if this instance has already been destroyed,
     * for example after its {@link SwiftArena} was closed.
     *
     * <b>API Note:</b> When using this pointer one must still ensure that the underlying object
     * is kept alive using some means (e.g. a class remains retained). This method prevents
     * reaching freed Swift memory after an explicit destroy, but does not otherwise guarantee
     * that the address remains valid.
     */
    long $memoryAddress();

    /**
     * Returns the cleanup associated with this instance.
     * <p>
     * The same cleanup instance is returned on every call. The cleanup also serves as the
     * destroyed-state holder, allowing callers to poll {@link SwiftInstanceCleanup#isDestroyed()}
     * even after this instance has been GC-ed.
     * <p>
     * <b>Warning:</b> The cleanup must not capture {@code this}.
     */
    SwiftInstanceCleanup $cleanup();

    /**
     * Ensures that this instance has not been destroyed.
     * <p>
     * If this object has been destroyed, calling this method will cause an {@link IllegalStateException}
     * to be thrown. This check should be performed before accessing {@code $memorySegment} to prevent
     * use-after-free errors.
     */
    default void $ensureAlive() {
        SwiftInstanceCleanup cleanup = this.$cleanup();
        if (cleanup != null && cleanup.isDestroyed()) {
            throw new IllegalStateException("Attempted to call method on already destroyed instance of " + getClass().getSimpleName() + "!");
        }
    }
}
