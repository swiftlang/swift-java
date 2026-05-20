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

import java.util.concurrent.atomic.AtomicIntegerFieldUpdater;

class JNISwiftInstanceCleanup implements SwiftInstanceCleanup {
    private static final AtomicIntegerFieldUpdater<JNISwiftInstanceCleanup> DESTROYED =
            AtomicIntegerFieldUpdater.newUpdater(JNISwiftInstanceCleanup.class, "destroyed");

    private final Runnable destroyFunction;

    @SuppressWarnings("unused") // accessed via DESTROYED field updater
    private volatile int destroyed;

    public JNISwiftInstanceCleanup(Runnable destroyFunction) {
        this.destroyFunction = destroyFunction;
    }

    @Override
    public boolean isDestroyed() {
        return destroyed != 0;
    }

    @Override
    public void run() {
        if (DESTROYED.compareAndSet(this, 0, 1)) {
            destroyFunction.run();
        } else {
            throw new IllegalStateException("Double destruction attempt detected!");
        }
    }
}
