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
    `maven-publish`
}

group = "org.swift.swiftkit"
version = "1.0-SNAPSHOT"

base {
    archivesName = "swiftkit-ffm"
}

repositories {
    mavenLocal()
    mavenCentral()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            groupId = group as? String
            artifactId = "swiftkit-ffm"
            version = "1.0-SNAPSHOT"

            from(components["java"])
        }
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(25))
    }
}

dependencies {
    implementation(projects.swiftKitCore)

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

/// Enable access to preview APIs, e.g. java.lang.foreign.* (Panama)
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("--enable-preview")
    options.compilerArgs.add("-Xlint:preview")
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
}
tasks.build {
    dependsOn(compileSwift)
}

registerCleanSwift(rootDir)