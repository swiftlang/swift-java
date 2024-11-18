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

package org.swift.swiftkit.gradle

final class BuildUtils {

    static String swiftCoreDylibPath() {
        def osName = System.getProperty("os.name")
        def isLinux = osName.toLowerCase(Locale.getDefault()).contains("linux")

        return isLinux ?
                "/usr/lib/swift/linux" :
                "/usr/lib/swift"
    }

    /// Find library paths for 'java.library.path' when running or testing projects inside this build.
    static def javaLibraryPaths(File rootDir) {
        def osName = System.getProperty("os.name")
        def osArch = System.getProperty("os.arch")
        def isLinux = osName.toLowerCase(Locale.getDefault()).contains("linux")
        def base = rootDir == null ? "" : "${rootDir}/"

        def debugPaths = [
                isLinux ?
                        /* Linux */ (osArch == "amd64" || osArch == "x86_64" ?
                        "${base}.build/x86_64-unknown-linux-gnu/debug/" :
                        "${base}.build/${osArch}-unknown-linux-gnu/debug/") :
                        /* macOS */ (osArch == "aarch64" ?
                        "${base}.build/arm64-apple-macosx/debug/" :
                        "${base}.build/${osArch}-apple-macosx/debug/"),
                isLinux ?
                        /* Linux */ (osArch == "amd64" || osArch == "x86_64" ?
                        "${base}../../.build/x86_64-unknown-linux-gnu/debug/" :
                        "${base}../../.build/${osArch}-unknown-linux-gnu/debug/") :
                        /* macOS */ (osArch == "aarch64" ?
                        "${base}../../.build/arm64-apple-macosx/debug/" :
                        "${base}../../.build/${osArch}-apple-macosx/debug/"),
        ]
        def releasePaths = debugPaths.collect { it.replaceAll("debug", "release") }
        def systemPaths =
                // system paths
                isLinux ?
                        [
                                swiftCoreDylibPath(),
                                // TODO: should we be Swiftly aware and then use the currently used path?
                                System.getProperty("user.home") + "/.local/share/swiftly/toolchains/6.0.2/usr/lib/swift/linux"
                        ] :
                        [
                                swiftCoreDylibPath(),
                        ]

        return releasePaths + debugPaths + systemPaths
    }
}
