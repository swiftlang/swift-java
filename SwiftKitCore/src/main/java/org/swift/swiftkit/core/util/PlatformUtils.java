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

public class PlatformUtils {
    public static boolean isLinux() {
        return System.getProperty("os.name").toLowerCase().contains("linux");
    }

    public static boolean isMacOS() {
        return System.getProperty("os.name").toLowerCase().contains("mac");
    }

    public static boolean isWindows() {
        return System.getProperty("os.name").toLowerCase().contains("windows");
    }

    public static boolean isAarch64() {
        return System.getProperty("os.arch").equals("aarm64");
    }

    public static boolean isAmd64() {
        String arch = System.getProperty("os.arch");
        return arch.equals("amd64") || arch.equals("x86_64");
    }

    public static String dynamicLibraryName(String base) {
        if (isLinux()) {
            return "lib" + uppercaseFistLetter(base) + ".so";
        } else {
            return "lib" + uppercaseFistLetter(base) + ".dylib";
        }
    }

    static String uppercaseFistLetter(String base) {
        if (base == null || base.isEmpty()) {
            return base;
        }
        return base.substring(0, 1).toUpperCase() + base.substring(1);
    }
}
