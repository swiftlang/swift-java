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
//===----------------------------------------------------------------------===

package org.swift.swiftkit.core;

/**
 * Base class of all Swift {@code Error} values surfaced to Java as exceptions.
 * <p>
 * The exception message is the Swift description of the wrapped error, i.e. {@code String(describing: error)}.
 */
@SuppressWarnings("serial")
public abstract class SwiftError extends Exception implements JNISwiftInstance, SwiftDowncastable {

    @Override
    public String getMessage() {
        // Loggers and stack trace printers call this implicitly, even after a confined arena has freed the
        // Swift value, so avoid reading freed memory
        if ($cleanup().isDestroyed()) {
            return "<destroyed " + getClass().getSimpleName() + ">";
        }
        return SwiftObjects.toString($memoryAddress(), $typeMetadataAddress());
    }
}
