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

import org.gradle.api.tasks.testing.logging.TestExceptionFormat
import java.util.*

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


// Configure paths for native (Swift) libraries
tasks.test {
    jvmArgs(
        "--enable-native-access=ALL-UNNAMED",

        // Include the library paths where our dylibs are that we want to load and call
        "-Djava.library.path=" + javaLibraryPaths().joinToString(File.pathSeparator)
    )
}

tasks.withType<Test> {
    this.testLogging {
        showStandardStreams = true
        exceptionFormat = TestExceptionFormat.FULL
    }
}


val buildSwiftJExtract = tasks.register<Exec>("buildSwiftJExtract") {
    description = "Builds Swift targets, including jextract-swift"

    workingDir("..")
    commandLine("make")
}

tasks.build {
    dependsOn(buildSwiftJExtract)
}

