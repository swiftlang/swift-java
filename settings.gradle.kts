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

include("SwiftKitCore")
include("SwiftKitFFM")

// Include sample apps -- you can run them via `gradle Name:run`
if (!(settings.providers.gradleProperty("skipSamples").orNull.toBoolean())) {
    File(rootDir, "Samples").listFiles().forEach {
        if (it.isDirectory && (File(it, "build.gradle").exists() || File(it, "build.gradle.kts").exists())) {
            include(":Samples:${it.name}")
        }
    }
}

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")
