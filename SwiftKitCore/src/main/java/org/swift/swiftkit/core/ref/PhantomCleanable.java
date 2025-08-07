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
    private final Cleaner cleaner;

    public PhantomCleanable(Object referent, Cleaner cleaner, Runnable cleanupAction) {
        super(referent, cleaner.referenceQueue);
        this.cleanupAction = cleanupAction;
        this.cleaner = cleaner;
        cleaner.list.add(this);
    }

    public void cleanup() {
        if (cleaner.list.remove(this)) {
            cleanupAction.run();
        }
    }
}
