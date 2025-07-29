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

package org.swift.swiftkit.core.primitives;

import org.swift.swiftkit.core.annotations.NonNull;

/**
 * Utility class used to convert from {@code Unsigned...} wrapper classes to their underlying representation,
 * without performing checks.
 *
 * <p>Primarily used by the jextract source generator. In non-generated code, prefer using {@code intValue()},
 * and the other value methods, which can return the specific type of primitive you might be interested in.
 */
public final class UnsignedNumbers {

    /**
     * Returns the primitive {@code int}, value of the passed in {@link UnsignedInteger}.
     */
    public static int toPrimitive(@NonNull UnsignedInteger value) {
        return value.intValue();
    }

    /**
     * Returns the primitive {@code long}, value of the passed in {@link UnsignedLong}.
     */
    public static long toPrimitive(@NonNull UnsignedLong value) {
        return value.longValue();
    }
}