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
import kotlin.system.exitProcess
import kotlinx.serialization.json.*

plugins {
    java
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(24)
    }
}

repositories {
    mavenCentral()
}

fun getSwiftRuntimeLibraryPaths(): List<String> {
    val process = ProcessBuilder("swiftc", "-print-target-info")
        .redirectError(ProcessBuilder.Redirect.INHERIT)
        .start()

    val output = process.inputStream.bufferedReader().use { it.readText() }
    val exitCode = process.waitFor()
    if (exitCode != 0) {
        System.err.println("Error executing swiftc -print-target-info")
        exitProcess(exitCode)
    }

    val json = Json.parseToJsonElement(output)
    val runtimeLibraryPaths = json.jsonObject["paths"]?.jsonObject?.get("runtimeLibraryPaths")?.jsonArray
    return runtimeLibraryPaths?.map { it.jsonPrimitive.content } ?: emptyList()
}

/**
 * Find library paths for 'java.library.path' when running or testing projects inside this build.
 */
// TODO: can't figure out how to share this code between BuildLogic/ and buildSrc/
fun javaLibraryPaths(rootDir: File): List<String> {
    val osName = System.getProperty("os.name").lowercase(Locale.getDefault())
    val osArch = System.getProperty("os.arch")
    val isLinux = osName.contains("linux")
    val base = rootDir.path.let { "$it/" }

    val projectBuildOutputPath =
        if (isLinux) {
            if (osArch == "amd64" || osArch == "x86_64")
                "$base.build/x86_64-unknown-linux-gnu"
            else
                "$base.build/${osArch}-unknown-linux-gnu"
        } else {
            if (osArch == "aarch64")
                "$base.build/arm64-apple-macosx"
            else
                "$base.build/${osArch}-apple-macosx"
        }
    val parentParentBuildOutputPath =
        "../../$projectBuildOutputPath"


    val swiftBuildOutputPaths = listOf(
        projectBuildOutputPath,
        parentParentBuildOutputPath
    )

    val debugBuildOutputPaths = swiftBuildOutputPaths.map { "$it/debug" }
    val releaseBuildOutputPaths = swiftBuildOutputPaths.map { "$it/release" }
    val swiftRuntimePaths = getSwiftRuntimeLibraryPaths()

    return debugBuildOutputPaths + releaseBuildOutputPaths + swiftRuntimePaths
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
