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

import java.util.*
import java.io.*

plugins {
    java
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(22)
    }
}

repositories {
    mavenCentral()
}

testing {
    suites {
        val test by getting(JvmTestSuite::class) {
            useJUnitJupiter("5.10.3")
        }
    }
}

/// Enable access to preview APIs, e.g. java.lang.foreign.* (Panama)
tasks.withType(JavaCompile::class).forEach {
    it.options.compilerArgs.add("--enable-preview")
    it.options.compilerArgs.add("-Xlint:preview")
}


// FIXME: cannot share definition with 'buildSrc' so we duplicated the impl here
fun javaLibraryPaths(dir: File): List<String> {
    val osName = System.getProperty("os.name")
    val osArch = System.getProperty("os.arch")
    val isLinux = osName.lowercase(Locale.getDefault()).contains("linux")

    return listOf(
        if (isLinux) {
            if (osArch.equals("x86_64") || osArch.equals("amd64")) {
                "$dir/.build/x86_64-unknown-linux-gnu/debug/"
            } else {
                "$dir/.build/$osArch-unknown-linux-gnu/debug/"
            }
        } else {
            if (osArch.equals("aarch64")) {
                "$dir/.build/arm64-apple-macosx/debug/"
            } else {
                "$dir/.build/$osArch-apple-macosx/debug/"
            }
        },
        if (isLinux) {
            "/usr/lib/swift/linux"
        } else {
            // assume macOS
            "/usr/lib/swift/"
        },
        if (isLinux) {
            System.getProperty("user.home") + "/.local/share/swiftly/toolchains/6.0.2/usr/lib/swift/linux"
        } else {
            // assume macOS
            "/usr/lib/swift/"
        }
    )
}


// Configure paths for native (Swift) libraries
tasks.test {
    jvmArgs(
        "--enable-native-access=ALL-UNNAMED",

        // Include the library paths where our dylibs are that we want to load and call
        "-Djava.library.path=" +
                (javaLibraryPaths(rootDir) + javaLibraryPaths(project.projectDir))
                    .joinToString(File.pathSeparator)
    )
}

tasks.withType<Test> {
    this.testLogging {
        this.showStandardStreams = true
    }
}
