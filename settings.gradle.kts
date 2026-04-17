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

pluginManagement {
    includeBuild("BuildLogic")
}

rootProject.name = "swift-java"

// ==== -----------------------------------------------------------------------
// MARK: JDK detection
//
// Some modules require JDK 25+ (FFM API). When the active toolchain is
// older we exclude those modules so developers with only JDK 17 can still
// build the JDK-17-compatible subset (currently SwiftKitCore).
//
// Resolution order:
//   1. -PswiftJavaJdk=<n> Gradle property (explicit override)
//   2. JAVA_HOME_25* env vars listed in gradle.properties (treated as 25)
//   3. JAVA_HOME/release file's JAVA_VERSION
//   4. Default: 25

fun detectJdkMajor(): Int {
    settings.providers.gradleProperty("swiftJavaJdk").orNull?.toIntOrNull()?.let { return it }

    val env = System.getenv()
    if (listOf("JAVA_HOME_25", "JAVA_HOME_25_X64", "JAVA_HOME_25_ARM64").any { env[it] != null }) {
        return 25
    }

    env["JAVA_HOME"]?.let { javaHome ->
        val release = File(javaHome, "release")
        if (release.isFile) {
            release.readLines().firstOrNull { it.startsWith("JAVA_VERSION=") }?.let { line ->
                val raw = line.substringAfter("=").trim().trim('"')
                val major = raw.substringBefore(".").toIntOrNull()
                    ?: raw.substringBefore("-").toIntOrNull()
                if (major != null) return major
            }
        }
    }
    return 25
}

val swiftJavaJdk = detectJdkMajor()
gradle.extra["swiftJavaJdk"] = swiftJavaJdk

val ffmCapable = swiftJavaJdk >= 22

// Modules and samples that depend on the FFM API (java.lang.foreign.*)
val ffmModules = setOf(
    "SwiftKitFFM",
    "SwiftJavaExtractFFMSampleApp",
    "SwiftAndJavaJarFFMSampleLib",
)

val skipped = mutableListOf<String>()

include("SwiftKitCore")
if (ffmCapable) {
    include("SwiftKitFFM")
} else {
    skipped += "SwiftKitFFM"
}

// Include sample apps -- you can run them via `gradle Name:run`
if (!(settings.providers.gradleProperty("skipSamples").orNull.toBoolean())) {
    File(rootDir, "Samples").listFiles()?.forEach {
        if (it.isDirectory && (File(it, "build.gradle").exists() || File(it, "build.gradle.kts").exists())) {
            val name = it.name
            if (name in ffmModules && !ffmCapable) {
                skipped += "Samples:$name"
            } else {
                include(":Samples:$name")
            }
        }
    }
}

if (skipped.isNotEmpty()) {
    println("[swift-java] JDK $swiftJavaJdk detected — skipping: ${skipped.joinToString(", ")}")
}

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")
