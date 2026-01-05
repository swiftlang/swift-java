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

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.swift.swiftkit.gradle.BuildUtils
import java.io.ByteArrayOutputStream
import java.io.File

import java.nio.file.*
import kotlin.concurrent.thread

plugins {
    id("build-logic.java-application-conventions")
    id("me.champeau.jmh") version "0.7.2"
    id("swiftpm-import-plugin")
}

group = "org.swift.swiftkit"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(25))
    }
}

// Add the java-swift generated Java sources


val cleanSwift = tasks.register("cleanSwift", Exec::class.java) {
    workingDir = layout.projectDirectory.asFile
    commandLine = listOf("swift")
    args("package", "clean")
}
tasks.clean {
    dependsOn("cleanSwift")
}

dependencies {
    implementation(project(":SwiftKitCore"))
    implementation(project(":SwiftKitFFM"))

    testRuntimeOnly("org.junit.platform:junit-platform-launcher") // TODO: workaround for not finding junit: https://github.com/gradle/gradle/issues/34512 // TODO: workaround for not finding junit: https://github.com/gradle/gradle/issues/34512
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

tasks.named("test", Test::class.java) {
    useJUnitPlatform()
}

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(25))
}

application {
    mainClass = "com.example.swift.HelloJava2Swift"
}

val jmhIncludes = findProperty("jmhIncludes") as? String

jmh {
    if (jmhIncludes != null) {
        includes.set(setOf(jmhIncludes))
    }

    jvmArgsAppend = listOf(
        "--enable-native-access=ALL-UNNAMED",

        "-Djava.library.path=" +
                ((BuildUtils.javaLibraryPaths(rootDir) as Iterable<String>) +
                 (BuildUtils.javaLibraryPaths(project.projectDir) as Iterable<String>)).joinToString(":"),

        // Enable tracing downcalls (to Swift)
        "-Djextract.trace.downcalls=false"
    )
}

swiftPMDependencies {
    `package`(
        url = url("https://github.com/abdulowork/SwiftPMImport.git"),
        version = exact("1.0.12"),
        products = listOf(product("SwiftPMImport", importedModules = setOf("SwiftTarget", "TargetWithAlgorithms"))),
    )

    localPackage(
        path = projectDir,
        products = listOf("MySwiftLibrary")
    )

    swiftJavaRepository.set(rootDir)
}