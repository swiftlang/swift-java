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

import java.util.concurrent.atomic.AtomicBoolean;

class JNISwiftInstanceCleanup implements SwiftInstanceCleanup {
    private final Runnable destroyFunction;
    private final AtomicBoolean statusDestroyedFlag;

    public JNISwiftInstanceCleanup(Runnable destroyFunction, AtomicBoolean statusDestroyedFlag) {
        this.destroyFunction = destroyFunction;
        this.statusDestroyedFlag = statusDestroyedFlag;
    }

    @Override
    public void run() {
        if (statusDestroyedFlag.compareAndSet(false, true)) {
            destroyFunction.run();
        } else {
            throw new IllegalStateException("Double destruction attempt detected!");
        }
    }
}
