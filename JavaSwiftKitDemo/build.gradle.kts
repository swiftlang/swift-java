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

plugins {
    id("build-logic.java-application-conventions")
}

group = "org.swift.javakit"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(22))
    }
}

dependencies {
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

tasks.test {
    useJUnitPlatform()
}

fun javaLibraryPaths(): List<String> {
    val osName = System.getProperty("os.name")
    val osArch = System.getProperty("os.arch")
    val isLinux = osName.lowercase(Locale.getDefault()).contains("linux")

    return listOf(
        if (osName.lowercase(Locale.getDefault()).contains("linux")) {
            """$rootDir/.build/$osArch-unknown-linux-gnu/debug/"""
        } else {
            if (osArch.equals("aarch64")) {
                """$rootDir/.build/arm64-apple-macosx/debug/"""
            } else {
                """$rootDir/.build/$osArch-apple-macosx/debug/"""
            }
        },
        if (isLinux) {
            "/usr/lib/swift/linux"
        } else {
            // assume macOS
            "/usr/lib/swift/"
        }
    )
}

application {
    mainClass = "org.example.HelloJava2Swift"

    // In order to silence:
    //   WARNING: A restricted method in java.lang.foreign.SymbolLookup has been called
    //   WARNING: java.lang.foreign.SymbolLookup::libraryLookup has been called by org.example.swift.JavaKitExample in an unnamed module
    //   WARNING: Use --enable-native-access=ALL-UNNAMED to avoid a warning for callers in this module
    //   WARNING: Restricted methods will be blocked in a future release unless native access is enabled
    // FIXME: Find out the proper solution to this
    applicationDefaultJvmArgs = listOf(
        "--enable-native-access=ALL-UNNAMED",

        // Include the library paths where our dylibs are that we want to load and call
        "-Djava.library.path=" + javaLibraryPaths().joinToString(File.pathSeparator),

        // Enable tracing downcalls (to Swift)
        "-Djextract.trace.downcalls=true"
    )
}

