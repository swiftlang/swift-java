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

/**
 * Utility functions, similar to @{link java.util.Objects}
 */
public class SwiftObjects {
    public static void requireNonZero(long number, String name) {
        if (number == 0) {
            throw new IllegalArgumentException(String.format("'%s' must not be zero!", name));
        }
    }
}
