//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.swiftkit.core.ref;

import java.lang.ref.PhantomReference;

public class PhantomCleanable extends PhantomReference<Object> {
    private final Runnable cleanupAction;
    private final SwiftCleaner swiftCleaner;

    public PhantomCleanable(Object referent, SwiftCleaner swiftCleaner, Runnable cleanupAction) {
        super(referent, swiftCleaner.referenceQueue);
        this.cleanupAction = cleanupAction;
        this.swiftCleaner = swiftCleaner;
        swiftCleaner.list.add(this);
    }

    public void cleanup() {
        if (swiftCleaner.list.remove(this)) {
            cleanupAction.run();
        }
    }
}
