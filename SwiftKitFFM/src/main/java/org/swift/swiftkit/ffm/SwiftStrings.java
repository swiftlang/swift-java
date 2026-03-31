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
//===----------------------------------------------------------------------===//

package org.swift.swiftkit.ffm;

import java.lang.foreign.*;

/**
 * Utility methods for converting between Java Strings and C strings (null-terminated UTF-8).
 */
public final class SwiftStrings {

    private SwiftStrings() {
        // Not instantiable
    }

    /**
     * Convert String to a MemorySegment filled with the C string.
     */
    public static MemorySegment toCString(String str, Arena arena) {
        return arena.allocateFrom(str);
    }

    /**
     * Read a heap-allocated C string into a Java String, then free the native memory.
     */
    public static String fromCString(MemorySegment cStr) {
        if (cStr.equals(MemorySegment.NULL)) return null;
        String result = cStr.reinterpret(Long.MAX_VALUE).getString(0);
        SwiftRuntime.cFree(cStr);
        return result;
    }
}
