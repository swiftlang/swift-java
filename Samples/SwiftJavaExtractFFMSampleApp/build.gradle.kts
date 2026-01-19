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
import utilities.javaLibraryPaths
import utilities.registerJextractTask

plugins {
    id("build-logic.java-application-conventions")
    id("me.champeau.jmh") version "0.7.2"
}

group = "org.swift.swiftkit"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(25))
    }
}


val jextract = registerJextractTask()

// Add the java-swift generated Java sources
sourceSets {
    main {
        java {
            srcDir(jextract)
        }
    }
    test {
        java {
            srcDir(jextract)
        }
    }
    this.jmh {
        java {
            srcDir(jextract)
        }
    }
}

tasks.build {
    dependsOn(jextract)
}

registerCleanSwift()

dependencies {
    implementation(projects.swiftKitCore)
    implementation(projects.swiftKitFFM)

    testRuntimeOnly(libs.junit.platform.launcher) // TODO: workaround for not finding junit: https://github.com/gradle/gradle/issues/34512
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
}

tasks.named<Test>("test") {
    useJUnitPlatform()
}

application {
    mainClass = "com.example.swift.HelloJava2Swift"

    applicationDefaultJvmArgs = listOf(
        "--enable-native-access=ALL-UNNAMED",
        // Include the library paths where our dylibs are that we want to load and call
        "-Djava.library.path=" + (javaLibraryPaths(rootDir) + javaLibraryPaths(project.projectDir)).joinToString(":"),
        // Enable tracing downcalls (to Swift)
        "-Djextract.trace.downcalls=true"
    )
}

val jmhIncludes = findProperty("jmhIncludes")

jmh {
    if (jmhIncludes != null) {
        includes = listOf(jmhIncludes.toString())
    }

    jvmArgsAppend = listOf(
        "--enable-native-access=ALL-UNNAMED",
        "-Djava.library.path=" + (javaLibraryPaths(rootDir) + javaLibraryPaths(project.projectDir)).joinToString(":"),
        // Enable tracing downcalls (to Swift)
        "-Djextract.trace.downcalls=false"
    )
}
