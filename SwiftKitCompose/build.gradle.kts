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

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    // Shared toolchain + native (Swift) library path wiring for tests.
    id("build-logic.java-common-conventions")

    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.compose.compiler)

    `maven-publish`
}

group = "org.swift.swiftkit"
version = "1.0-SNAPSHOT"
base {
    archivesName = "swiftkit-compose"
}

repositories {
    mavenLocal()
    mavenCentral()
    google()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            groupId = group as? String
            artifactId = "swiftkit-compose"
            version = "1.0-SNAPSHOT"

            from(components["java"])
        }
    }
}

dependencies {
    api(project(":SwiftKitCore"))

    api(libs.compose.runtime)

    testRuntimeOnly(libs.junit.platform.launcher) // TODO: workaround for not finding junit: https://github.com/gradle/gradle/issues/34512
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
}

// Compile down to Java 11 bytecode to match SwiftKitCore's consumability floor
// (and Android's typical desugaring target).
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(11)
}

testing {
    suites {
        val test by getting(JvmTestSuite::class) {
            useJUnitJupiter()
        }
    }
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
    }
}
