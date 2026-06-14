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
    repositories {
        gradlePluginPortal()
        // Android Gradle Plugin (com.android.*) markers are published to Google's Maven.
        google()
        mavenCentral()
    }
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

// ==== -----------------------------------------------------------------------
// MARK: Android SDK detection
//
// The Android Compose sample applies the Android Gradle Plugin, which requires
// an Android SDK. Contributors without one (and most CI jobs) should still be
// able to build everything else, so we exclude the sample when no SDK is found.
//
// Resolution order: ANDROID_HOME / ANDROID_SDK_ROOT env vars, then a sdk.dir
// entry in local.properties.
fun detectAndroidSdk(): Boolean {
    val env = System.getenv()
    if (listOf("ANDROID_HOME", "ANDROID_SDK_ROOT").any { env[it]?.let { dir -> File(dir).isDirectory } == true }) {
        return true
    }
    val localProperties = File(rootDir, "local.properties")
    if (localProperties.isFile) {
        return localProperties.readLines().any { it.trim().startsWith("sdk.dir=") }
    }
    return false
}

val androidAvailable = detectAndroidSdk()

// Samples that apply the Android Gradle Plugin.
val androidModules = setOf(
    "SwiftKitAndroidComposeSample",
)

val skipped = mutableListOf<String>()

include("SwiftKitCore")
// Kotlin + Compose helpers for the Swift @Observable bridge. Pure JVM (no Android
// Gradle Plugin), so it builds on the same JDK matrix as SwiftKitCore.
include("SwiftKitCompose")
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
                skipped += "Samples:$name (needs JDK 22+ for FFM)"
            } else if (name in androidModules && !androidAvailable) {
                skipped += "Samples:$name (needs an Android SDK)"
            } else {
                include(":Samples:$name")
            }
        }
    }
}

if (skipped.isNotEmpty()) {
    println("[swift-java] JDK $swiftJavaJdk, Android SDK ${if (androidAvailable) "available" else "absent"} — skipping: ${skipped.joinToString(", ")}")
}

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")
