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

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

repositories {
    gradlePluginPortal()
    mavenCentral()
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json-jvm:1.7.3")
}

plugins {
    `kotlin-dsl`
}

kotlin {
    jvmToolchain(25)

    compilerOptions {
        // Kotlin does not yet support  JDK 25, so we use 24 for kotlin specifically
        // in order to avoid this warning: "Kotlin does not yet support 25 JDK target, falling back to Kotlin JVM_24 JVM target"
        jvmTarget.set(JvmTarget.JVM_24)
    }
}
