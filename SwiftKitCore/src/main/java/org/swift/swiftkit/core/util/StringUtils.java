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

package org.swift.swiftkit.core.util;

public class StringUtils {
    public static String stripPrefix(String mangledName, String prefix) {
        if (mangledName.startsWith(prefix)) {
            return mangledName.substring(prefix.length());
        }
        return mangledName;
    }

    public static String stripSuffix(String mangledName, String suffix) {
        if (mangledName.endsWith(suffix)) {
            return mangledName.substring(0, mangledName.length() - suffix.length());
        }
        return mangledName;
    }

    public static String hexString(long number) {
        return String.format("0x%02x", number);
    }

}
