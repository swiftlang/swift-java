//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.build.utils

import org.gradle.api.Project

/**
 * Resolve the publication version for swift-java's Java artifacts.
 *
 * Resolution order:
 * 1. `-PswiftkitVersion=<value>` project property, for CI/release overrides.
 * 2. `git describe --tags --always`, for normal local builds with full git history.
 * 3. `GITHUB_SHA` (truncated) — useful in shallow CI checkouts where git history is not available.
 * 4. `0.0.0-SNAPSHOT` fallback.
 *
 * `git describe` is allowed to fail without breaking the build, because some CI
 * environments do not have a full checkout (e.g. `fetch-depth: 1`) or any tags
 * reachable, in which case the command exits with code 128.
 */
fun Project.resolveSwiftKitVersion(): String {
    findProperty("swiftkitVersion")?.toString()?.takeIf { it.isNotBlank() }?.let { return it }

    val gitVersion = runCatching {
        providers.exec {
            commandLine("git", "describe", "--tags", "--always")
            workingDir = rootDir
            isIgnoreExitValue = true
        }.standardOutput.asText.get().trim()
    }.getOrNull()
    if (!gitVersion.isNullOrBlank()) return gitVersion

    System.getenv("GITHUB_SHA")?.take(12)?.takeIf { it.isNotBlank() }?.let { return it }

    return "0.0.0-SNAPSHOT"
}
