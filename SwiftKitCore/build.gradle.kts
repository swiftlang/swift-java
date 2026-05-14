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
    id("build-logic.java-application-conventions")
    id("me.champeau.jmh") version "0.7.2"
    `maven-publish`
}

group = "org.swift.swiftkit"
version = "1.0-SNAPSHOT"
base {
    archivesName = "swiftkit-core"
}

repositories {
    mavenLocal()
    mavenCentral()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            groupId = group as? String
            artifactId = "swiftkit-core"
            version = "1.0-SNAPSHOT"

            from(components["java"])
        }
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of((gradle.extra.properties["swiftJavaJdk"] as? Int) ?: 25))
    }
}

tasks.withType<JavaCompile>().configureEach {
    // SwiftKitCore is consumable down to Java 11
    options.release.set(11)
}

dependencies {
    testRuntimeOnly(libs.junit.platform.launcher) // TODO: workaround for not finding junit: https://github.com/gradle/gradle/issues/34512
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
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

// SwiftKit depends on SwiftRuntimeFunctions (Swift library that this Java library calls into)

val compileSwift = tasks.register<Exec>("compileSwift") {
    description = "Compile the swift-java SwiftRuntimeFunctions dynamic library that SwiftKit (Java) calls into"

    inputs.file(File(rootDir, "Package.swift"))
    inputs.dir(File(rootDir, "Sources/")) // a bit generous, but better safe than sorry, and include all Swift source changes
    outputs.dir(File(rootDir, ".build"))

    workingDir = rootDir
    commandLine("swift")
    // FIXME: disable prebuilts until swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418
    args("build", "--disable-experimental-prebuilts", "--target", "SwiftRuntimeFunctions")

    // When this task runs inside an outer swift-build-driven invocation (e.g.
    // JExtractSwiftPlugin -> java-callbacks-build -> gradle -> here) the outer
    // build leaks Xcode-style build settings (SDKROOT=/, TOOLCHAINS, SDK_*,
    // SWIFTC_PASS_*) into the subprocess environment, which breaks the nested
    // swift build with "unable to resolve run destination SDK: '/'". Strip
    // them so the inner invocation resolves its own defaults.
    listOf(
        "SDKROOT", "SDK_DIR", "SDK_DIR_linux", "SDK_NAME", "SDK_NAMES",
        "SDK_VERSION", "SDK_VERSION_ACTUAL", "SDK_VERSION_MAJOR", "SDK_VERSION_MINOR",
        "SDK_STAT_CACHE_DIR", "SDK_STAT_CACHE_ENABLE", "SDK_STAT_CACHE_PATH",
        "SWIFTC_PASS_SDKROOT", "SWIFTC_PASS_SYSROOT", "TOOLCHAINS",
    ).forEach { environment.remove(it) }
}
tasks.build {
    dependsOn(compileSwift)
}

registerCleanSwift(rootDir)