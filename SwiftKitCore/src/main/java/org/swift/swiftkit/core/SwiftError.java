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

import java.util.Arrays;

/**
 * Base class of all Swift {@code Error} values surfaced to Java as exceptions.
 * <p>
 * The exception message is the Swift description of the wrapped error, i.e. {@code String(describing: error)}.
 * <p>
 * <b>Stack traces:</b> Constructing a {@link SwiftError} does not walk the stack, because errors are
 * also returned from Swift as ordinary values, where capturing a stack trace would be wasted work.
 * The stack trace is captured by {@link #$captureStackTrace()}, which the Swift throw path calls right
 * before the exception is thrown. A value that was obtained as a normal return value and is later thrown
 * by the user therefore has no stack trace.
 */
@SuppressWarnings("serial")
public abstract class SwiftError extends Exception implements JNISwiftInstance, SwiftDowncastable {

    @Override
    public String getMessage() {
        // Messages are read by loggers and stack trace printers, so don't throw on a destroyed instance
        if ($cleanup().isDestroyed()) {
            return "<destroyed " + getClass().getSimpleName() + ">";
        }
        return SwiftObjects.toString($memoryAddress(), $typeMetadataAddress());
    }

    /**
     * Does not capture the stack trace, see {@link #$captureStackTrace()}.
     */
    @Override
    public synchronized Throwable fillInStackTrace() {
        return this;
    }

    /**
     * Captures the current stack trace, dropping the leading frames that belong to {@link SwiftError} itself.
     * <p>
     * Called from Swift right before this error is thrown into Java.
     */
    public final void $captureStackTrace() {
        super.fillInStackTrace();
        StackTraceElement[] trace = getStackTrace();
        int skip = 0;
        while (skip < trace.length && trace[skip].getClassName().equals(SwiftError.class.getName())) {
            skip++;
        }
        if (skip > 0) {
            setStackTrace(Arrays.copyOfRange(trace, skip, trace.length));
        }
    }
}
