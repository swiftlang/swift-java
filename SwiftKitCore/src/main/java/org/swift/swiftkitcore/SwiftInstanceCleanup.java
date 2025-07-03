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

package org.swift.swiftkitcore;

/**
 * A Swift memory instance cleanup, e.g. count-down a reference count and destroy a class, or destroy struct/enum etc.
 */
public final class SwiftInstanceCleanup implements Runnable {
    // TODO: Should this be a weak reference?
    private final SwiftInstance swiftInstance;

    public SwiftInstanceCleanup(SwiftInstance swiftInstance) {
        this.swiftInstance = swiftInstance;
    }

    @Override
    public void run() {
        swiftInstance.$statusDestroyedFlag().set(true);

        // System.out.println("[debug] Destroy swift value [" + selfType.getSwiftName() + "]: " + selfPointer);
        swiftInstance.destroy();
    }
}