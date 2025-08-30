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

public interface JNISwiftInstance extends SwiftInstance {
    /**
     * Creates a function that will be called when the value should be destroyed.
     * This will be code-generated to call a native method to do deinitialization and deallocation.
     * <p>
     * The reason for this "indirection" is that we cannot have static methods on abstract classes,
     * and we can't define the destroy method as a member method, because we assume that the wrapper
     * has been released, when we destroy.
     * <p>
     * <b>Warning:</b> The function must not capture {@code this}.
     *
     * @return a function that is called when the value should be destroyed.
     */
    Runnable $createDestroyFunction();

    long $typeMetadataAddress();

    @Override
    default SwiftInstanceCleanup $createCleanup() {
        var statusDestroyedFlag = $statusDestroyedFlag();
        Runnable markAsDestroyed = () -> statusDestroyedFlag.set(true);

        return new JNISwiftInstanceCleanup(this.$createDestroyFunction(), markAsDestroyed);
    }
}
