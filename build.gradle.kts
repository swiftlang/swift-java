//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

plugins {
    base
}

// ==== -----------------------------------------------------------------------
// MARK: Version
//
// Derived from git tags, so CI checkouts need the tag history (`fetch-depth: 0`):
//   - HEAD is exactly at an `N.N.N` tag -> that version (a release)
//   - otherwise                         -> the latest tag with patch + 1, plus `-SNAPSHOT`
//   - no tags at all                    -> `0.0.1-SNAPSHOT`
//
// `-PswiftkitVersion=<version>` overrides the derived version.

val tagPattern = Regex("""^\d+\.\d+\.\d+$""")
val releaseTagGlob = "[0-9]*.[0-9]*.[0-9]*" // only consider release tags

fun runGit(vararg args: String): String? = try {
    val process = ProcessBuilder("git", *args)
        .directory(rootDir)
        .redirectErrorStream(false)
        .start()
    val out = process.inputStream.bufferedReader().readText().trim()
    process.errorStream.bufferedReader().readText() // drain
    if (process.waitFor() == 0 && out.isNotEmpty()) out else null
} catch (_: Exception) {
    null
}

fun computeVersion(): String {
    val exact = runGit("describe", "--exact-match", "--tags", "--match", releaseTagGlob, "HEAD")
    if (exact != null && tagPattern.matches(exact)) {
        return exact
    }
    val latest = runGit("describe", "--tags", "--abbrev=0", "--match", releaseTagGlob)
    val (major, minor, patch) = if (latest != null && tagPattern.matches(latest)) {
        latest.split(".").map { it.toInt() }
    } else {
        listOf(0, 0, 0)
    }
    return "$major.$minor.${patch + 1}-SNAPSHOT"
}

val computedVersion: String = providers.gradleProperty("swiftkitVersion").orNull
    ?.takeIf { it.isNotBlank() }
    ?: computeVersion()

allprojects {
    version = computedVersion
}

// `./gradlew -q printVersion` prints the resolved version
tasks.register("printVersion") {
    doLast { println(computedVersion) }
}

// ==== -----------------------------------------------------------------------
// MARK: Publishing
//
// The published modules (SwiftKitCore, SwiftKitFFM, SwiftKitNative) apply
// build-logic.java-publishing-conventions, which gives them two repositories:
//
//   ./gradlew publishAllPublicationsToStagingRepository   # to build/staging-deploy
//   ./gradlew publishAllPublicationsToSonatypeRepository  # to Maven Central
//
// The version decides where `sonatype` uploads to:
//   - `X.Y.Z`          -> the Central Portal's OSSRH Staging API. publish.yml then
//                         turns the upload into a deployment, which Central
//                         publishes as soon as it has validated it.
//   - `X.Y.Z-SNAPSHOT` -> https://central.sonatype.com/repository/maven-snapshots/
//
// Credentials and the signing key come from the environment, see RELEASING.md.
