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

    /// Find library paths for 'java.library.path' when running or testing projects inside this build.
    static def javaLibraryPaths(File rootDir) {
        def osName = System.getProperty("os.name")
        def osArch = System.getProperty("os.arch")
        def isLinux = osName.toLowerCase(Locale.getDefault()).contains("linux")

        return [
                isLinux ?
                        /* Linux */(osArch == "amd64" || osArch == "amd64" ?
                                "${rootDir}/.build/x86_64-unknown-linux-gnu/debug/" :
                                "${rootDir}/.build/${osArch}-unknown-linux-gnu/debug/") :
                        /* macOS */(osArch == "aarch64" ?
                                "${rootDir}/.build/arm64-apple-macosx/debug/" :
                                "${rootDir}/.build/${osArch}-apple-macosx/debug/"),
                isLinux ?
                        "/usr/lib/swift/linux" :
                        // assume macOS
                        "/usr/lib/swift/"
        ]
    }

}
