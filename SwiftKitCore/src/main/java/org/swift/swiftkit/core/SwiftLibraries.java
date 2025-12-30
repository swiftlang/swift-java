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

    // Library names of core Swift and SwiftRuntimeFunctions
    public static final String LIB_NAME_SWIFT_CORE = "swiftCore";
    public static final String LIB_NAME_SWIFT_CONCURRENCY = "swift_Concurrency";
    public static final String LIB_NAME_SWIFT_RUNTIME_FUNCTIONS = "SwiftRuntimeFunctions";
    public static final String LIB_NAME_SWIFT_JAVA = "SwiftJava";

    /** 
     * Allows for configuration if jextracted types should automatically attempt to load swiftCore and the library type is from.
     * <p/>
     * If all libraries you need to load are available in paths passed to {@code -Djava.library.path} this should work correctly,
     * however if attempting to load libraries from e.g. the jar as a resource, you may want to disable this.
     */
    public static final boolean AUTO_LOAD_LIBS = System.getProperty("swift-java.auto-load-libraries") == null ? 
            true
            : Boolean.getBoolean("swiftkit.auto-load-libraries");

    @SuppressWarnings("unused")
    private static final boolean INITIALIZED_LIBS = AUTO_LOAD_LIBS ? loadLibraries(false) : true;

    public static boolean loadLibraries(boolean loadSwiftRuntimeFunctions) {
        try {
            System.loadLibrary(LIB_NAME_SWIFT_CORE);
            System.loadLibrary(LIB_NAME_SWIFT_JAVA);
            if (loadSwiftRuntimeFunctions) {
                System.loadLibrary(LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
            }
            return true;
        } catch (UnsatisfiedLinkError e) {
            // Libraries not on path - will be loaded later from JAR or other location
            if (CallTraces.TRACE_DOWNCALLS) {
                System.err.println("[swift-java] Could not auto-load libraries from java.library.path: " + e.getMessage());
                System.err.println("[swift-java] Libraries will need to be loaded explicitly or from JAR resources");
            }
            return false;
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // Loading libraries

    // Cache of already-loaded libraries to prevent duplicate extraction
    private static final java.util.Map<String, File> loadedLibraries = new java.util.HashMap<>();

    public static synchronized void loadResourceLibrary(String libname) {
        // Check if already loaded
        if (loadedLibraries.containsKey(libname)) {
            if (CallTraces.TRACE_DOWNCALLS) {
                System.out.println("[swift-java] Library already loaded from cache: " + libname);
            }
            return;
        }

        String resourceName = PlatformUtils.dynamicLibraryName(libname);
        if (CallTraces.TRACE_DOWNCALLS) {
            System.out.println("[swift-java] Loading resource library: " + resourceName);
        }

        try (InputStream libInputStream = SwiftLibraries.class.getResourceAsStream("/" + resourceName)) {
            if (libInputStream == null) {
                throw new RuntimeException("Expected library '" + libname + "' ('" + resourceName + "') was not found as resource!");
            }

            // Extract to temp file
            File tempFile = File.createTempFile(libname, "");
            tempFile.deleteOnExit();
            Files.copy(libInputStream, tempFile.toPath(), StandardCopyOption.REPLACE_EXISTING);

            System.load(tempFile.getAbsolutePath());

            // Cache the loaded library
            loadedLibraries.put(libname, tempFile);

            if (CallTraces.TRACE_DOWNCALLS) {
                System.out.println("[swift-java] Loaded and cached library: " + libname + " from " + tempFile.getAbsolutePath());
            }
        } catch (IOException e) {
            throw new RuntimeException("Failed to load dynamic library '" + libname + "' ('" + resourceName + "') as resource!", e);
        }
    }

    public static String getJavaLibraryPath() {
        return System.getProperty("java.library.path");
    }
}
