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
import utilities.registerJextractTask

plugins {
    id("build-logic.java-library-conventions")
    id("com.google.osdetector") version "1.7.3"
    `maven-publish`
}

group = "org.swift.swiftkit"
version = "1.0-SNAPSHOT"

val swiftBuildConfiguration = "release"

repositories {
    mavenLocal()
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(25))
    }
}

dependencies {
    implementation(projects.swiftKitCore)
    implementation(projects.swiftKitFFM)

    testRuntimeOnly(libs.junit.platform.launcher) // TODO: workaround for not finding junit: https://github.com/gradle/gradle/issues/34512
    testImplementation(platform(libs.junit.bom))
    testImplementation(libs.junit.jupiter)
}

val jextract = registerJextractTask()

// Add the java-swift generated Java sources
sourceSets {
    main {
        java {
            srcDir(jextract)
        }
    }
    test {
        java {
            srcDir(jextract)
        }
    }
}

tasks.build {
    dependsOn(jextract)
}

tasks.named<Test>("test") {
    useJUnitPlatform()
}


// ==== Jar publishing

tasks.processResources.configure {
    dependsOn(jextract)
    val dylibs = listOf(
        "${layout.projectDirectory}/.build/${swiftBuildConfiguration}/libSwiftKitSwift.dylib"
    ) + swiftProductDylibPaths(swiftBuildConfiguration)
    from(dylibs)
}

tasks.jar.configure {
    archiveClassifier = osdetector.classifier
}

base {
    archivesName = "swift-and-java-jar-sample-lib"
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            artifactId = "swift-and-java-jar-sample-lib"
            from(components["java"])
        }
    }
    repositories {
        mavenLocal()
    }
}
