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

// Configure paths for native (Swift) libraries
tasks.test {
    jvmArgs(
        "--enable-native-access=ALL-UNNAMED",

        // Include the library paths where our dylibs are that we want to load and call
        "-Djava.library.path=" + listOf(
            """$rootDir/.build/arm64-apple-macosx/debug/""",
            "/usr/lib/swift/"
        ).joinToString(File.pathSeparator)
    )
}

tasks.withType<Test> {
    this.testLogging {
        this.showStandardStreams = true
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

