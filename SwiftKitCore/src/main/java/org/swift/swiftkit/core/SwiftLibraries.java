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

import org.swift.swiftkit.core.util.PlatformUtils;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

public final class SwiftLibraries {

    public static final String STDLIB_DYLIB_NAME = "swiftCore";
    public static final String SWIFTKITSWIFT_DYLIB_NAME = "SwiftKitSwift";
    public static final boolean TRACE_DOWNCALLS = Boolean.getBoolean("jextract.trace.downcalls");

    private static final String STDLIB_MACOS_DYLIB_PATH = "/usr/lib/swift/libswiftCore.dylib";

    @SuppressWarnings("unused")
    private static final boolean INITIALIZED_LIBS = loadLibraries(false);

    public static boolean loadLibraries(boolean loadSwiftKit) {
        System.loadLibrary(STDLIB_DYLIB_NAME);
        if (loadSwiftKit) {
            System.loadLibrary(SWIFTKITSWIFT_DYLIB_NAME);
        }
        return true;
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // Loading libraries

    public static void loadLibrary(String libname) {
        // TODO: avoid concurrent loadResource calls; one load is enough esp since we cause File IO when we do that
        try {
            // try to load a dylib from our classpath, e.g. when we included it in our jar
            loadResourceLibrary(libname);
        } catch (UnsatisfiedLinkError | RuntimeException e) {
            // fallback to plain system path loading
            System.loadLibrary(libname);
        }
    }

    public static void loadResourceLibrary(String libname) {
        String resourceName = PlatformUtils.dynamicLibraryName(libname);
        if (SwiftLibraries.TRACE_DOWNCALLS) {
            System.out.println("[swift-java] Loading resource library: " + resourceName);
        }

        try (InputStream libInputStream = SwiftLibraries.class.getResourceAsStream("/" + resourceName)) {
            if (libInputStream == null) {
                throw new RuntimeException("Expected library '" + libname + "' ('" + resourceName + "') was not found as resource!");
            }

            // TODO: we could do an in memory file system here
            File tempFile = File.createTempFile(libname, "");
            tempFile.deleteOnExit();
            Files.copy(libInputStream, tempFile.toPath(), StandardCopyOption.REPLACE_EXISTING);

            System.load(tempFile.getAbsolutePath());
        } catch (IOException e) {
            throw new RuntimeException("Failed to load dynamic library '" + libname + "' ('" + resourceName + "') as resource!", e);
        }
    }

    public static String getJavaLibraryPath() {
        return System.getProperty("java.library.path");
    }
}
