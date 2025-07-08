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

class JNISwiftInstanceCleanup implements SwiftInstanceCleanup {
    private final Runnable destroyFunction;
    private final Runnable markAsDestroyed;

    public JNISwiftInstanceCleanup(Runnable destroyFunction, Runnable markAsDestroyed) {
        this.destroyFunction = destroyFunction;
        this.markAsDestroyed = markAsDestroyed;
    }

    @Override
    public void run() {
        markAsDestroyed.run();
        destroyFunction.run();
    }
}
