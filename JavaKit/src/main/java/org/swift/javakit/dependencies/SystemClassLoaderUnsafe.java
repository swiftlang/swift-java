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

package org.swift.javakit.dependencies;

import java.io.File;
import java.net.URL;
import java.net.URLClassLoader;

public final class SystemClassLoaderUnsafe {

    private SystemClassLoaderUnsafe() {}

    /**
     * Use internal methods to add a path to the system classloader.
     * If this ever starts throwing in new JDK versions, we may need to abandon this technique.
     *
     * @param path path to add to the current system classloader.
     */
    public static void addPath(String path) {
        try {
            var url = new File(path).toURI().toURL();
            var urlClassLoader = (URLClassLoader) ClassLoader.getSystemClassLoader();
            var method = URLClassLoader.class.getDeclaredMethod("addURL", URL.class);
            method.setAccessible(true);
            method.invoke(urlClassLoader, url);
        } catch (Throwable ex) {
            throw new RuntimeException("Unable to add path to system class loader! " +
                    "This is not supported API and may indeed start failing in the future. " +
                    "If/when this happens, we have to change the bootstrap logic to instead " +
                    "create a new JVM with the new bootstrap classpath, " +
                    "rather than add paths to the existing one.", ex);
        }
    }
}
