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
            loadLibraryWithFallbacks(LIB_NAME_SWIFT_CORE);
            loadLibraryWithFallbacks(LIB_NAME_SWIFT_JAVA);
            if (loadSwiftRuntimeFunctions) {
                loadLibraryWithFallbacks(LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
            }
            return true;
        } catch (RuntimeException e) {
            // Libraries could not be loaded
            if (CallTraces.TRACE_DOWNCALLS) {
                System.err.println("[swift-java] Could not load libraries: " + e.getMessage());
                System.err.println("[swift-java] Libraries will need to be loaded explicitly or from JAR resources");
            }
            return false;
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // Loading libraries

    /**
     * Returns the platform-specific system path to the swiftCore library.
     *
     * @return Full path to swiftCore on the system, or null if platform is not macOS or Linux
     */
    public static String libSwiftCorePath() {
        if (PlatformUtils.isMacOS()) {
            return "/usr/lib/swift/libswiftCore.dylib";
        } else if (PlatformUtils.isLinux()) {
            return "/usr/lib/swift/linux/libswiftCore.so";
        }
        return null;
    }

    /**
     * Attempts to load a library using multiple fallback strategies with nice error reporting.
     * Tries in order: java.library.path, JAR resources, system path (for swiftCore only).
     *
     * @param libname The library name to load
     * @throws RuntimeException if all loading strategies fail
     */
    public static void loadLibraryWithFallbacks(String libname) {
        // Try 1: Load from java.library.path
        try {
            System.loadLibrary(libname);
            if (CallTraces.TRACE_DOWNCALLS) {
                System.out.println("[swift-java] Loaded " + libname + " from java.library.path");
            }
            return;
        } catch (Throwable e) {
            if (CallTraces.TRACE_DOWNCALLS) {
                System.err.println("[swift-java] Failed to load " + libname + " from java.library.path: " + e.getMessage());
            }
        }

        // Try 2: Load from JAR resources
        try {
            loadResourceLibrary(libname);
            if (CallTraces.TRACE_DOWNCALLS) {
                System.out.println("[swift-java] Loaded " + libname + " from JAR resources");
            }
            return;
        } catch (Throwable e2) {
            if (CallTraces.TRACE_DOWNCALLS) {
                System.err.println("[swift-java] Failed to load " + libname + " from JAR: " + e2.getMessage());
            }

            // Try 3: For swiftCore only, try system path
            if (libname.equals(LIB_NAME_SWIFT_CORE)) {
                String systemPath = libSwiftCorePath();
                if (systemPath != null) {
                    try {
                        System.load(systemPath);
                        if (CallTraces.TRACE_DOWNCALLS) {
                            System.out.println("[swift-java] Loaded " + libname + " from system path: " + systemPath);
                        }
                        return;
                    } catch (Throwable e3) {
                        throw new RuntimeException(
                            "Failed to load " + libname + " from java.library.path, JAR resources, and system path (" + systemPath + ")",
                            e3
                        );
                    }
                } else {
                    if (CallTraces.TRACE_DOWNCALLS) {
                        System.err.println("[swift-java] System path not available on this platform");
                    }
                }
            }

            throw new RuntimeException("Failed to load " + libname + " from java.library.path and JAR resources", e2);
        }
    }

    // Cache of already-loaded libraries to prevent duplicate extraction
    private static final java.util.concurrent.ConcurrentHashMap<String, File> loadedLibraries = new java.util.concurrent.ConcurrentHashMap<>();

    public static void loadResourceLibrary(String libname) {
        loadedLibraries.computeIfAbsent(libname, key -> {
            String resourceName = PlatformUtils.dynamicLibraryName(key);
            if (CallTraces.TRACE_DOWNCALLS) {
                System.out.println("[swift-java] Loading resource library: " + resourceName);
            }

            try (InputStream libInputStream = SwiftLibraries.class.getResourceAsStream("/" + resourceName)) {
                if (libInputStream == null) {
                    throw new RuntimeException("Expected library '" + key + "' ('" + resourceName + "') was not found as resource!");
                }

                // TODO: we could do an in memory file system here
                // Extract to temp file
                File tempFile = File.createTempFile(key, "");
                tempFile.deleteOnExit();
                Files.copy(libInputStream, tempFile.toPath(), StandardCopyOption.REPLACE_EXISTING);

                System.load(tempFile.getAbsolutePath());

                if (CallTraces.TRACE_DOWNCALLS) {
                    System.out.println("[swift-java] Loaded and cached library: " + key + " from " + tempFile.getAbsolutePath());
                }

                return tempFile;
            } catch (IOException e) {
                throw new RuntimeException("Failed to load dynamic library '" + key + "' ('" + resourceName + "') as resource!", e);
            }
        });

        if (CallTraces.TRACE_DOWNCALLS) {
            System.out.println("[swift-java] Library already loaded from cache: " + libname);
        }
    }

    public static String getJavaLibraryPath() {
        return System.getProperty("java.library.path");
    }
}
