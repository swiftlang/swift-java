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

// The Swift libraries that swiftkit-core and swiftkit-ffm load at runtime
// (libSwiftJava, libSwiftRuntimeFunctions), published as `swiftkit-native` with
// one classifier jar per platform, e.g. `swiftkit-native-<version>-osx-aarch_64.jar`.
//
// The libraries sit at the root of each classifier jar, which is where
// `SwiftLibraries.loadResourceLibrary` looks for them.
//
// Where the libraries come from:
//   -PnativeLibsDir=<dir>  one sub-directory per classifier, holding the libraries
//                          built on that platform (CI, see .github/workflows/publish.yml)
//   otherwise              built for this machine with `swift build -c release`,
//                          with a classifier like `osx-aarch_64` or `linux-x86_64`

plugins {
    id("build-logic.java-publishing-conventions")
}

base {
    archivesName = "swiftkit-native"
}
description = "Swift native libraries needed at runtime by swiftkit-core and swiftkit-ffm, one classifier jar per platform."

val nativeLibraries = listOf("SwiftRuntimeFunctions", "SwiftJava")

// ==== -----------------------------------------------------------------------
// MARK: Native libraries for this machine

// One invocation per product: `swift build` with several `--product` flags only
// builds the last one.
val swiftBuildTasks = nativeLibraries.map { product ->
    tasks.register<Exec>("swiftBuild$product") {
        group = "swift"
        description = "Build lib$product in release mode"
        workingDir = rootDir
        commandLine("swift", "build", "--disable-experimental-prebuilts", "-c", "release", "--product", product)
    }
}

fun hostClassifier(): String {
    val os = System.getProperty("os.name").lowercase()
    val osPart = when {
        os.contains("mac") -> "osx"
        os.contains("linux") -> "linux"
        else -> os.substringBefore(' ')
    }
    val arch = when (val arch = System.getProperty("os.arch")) {
        "aarch64", "arm64" -> "aarch_64"
        "amd64", "x86_64" -> "x86_64"
        else -> arch
    }
    return "$osPart-$arch"
}

// ==== -----------------------------------------------------------------------
// MARK: Classifier jars

// classifier -> directory containing that platform's libraries
val platformLibraries: Map<String, FileCollection> =
    when (val nativeLibsDir = providers.gradleProperty("nativeLibsDir").orNull?.let { rootProject.file(it) }) {
        null -> mapOf(hostClassifier() to files(rootDir.resolve(".build/release")).builtBy(swiftBuildTasks))
        else -> {
            val dirs = nativeLibsDir.listFiles { file -> file.isDirectory }.orEmpty().sortedBy { it.name }
            require(dirs.isNotEmpty()) { "-PnativeLibsDir=$nativeLibsDir has no per-classifier sub-directories" }
            dirs.forEach { dir ->
                val missing = nativeLibraries.filter { lib -> listOf("dylib", "so").none { dir.resolve("lib$lib.$it").isFile } }
                require(missing.isEmpty()) { "$dir is missing native libraries: $missing" }
            }
            dirs.associate { it.name to files(it) }
        }
    }

val swiftVersion: String? = providers.gradleProperty("swiftVersion").orNull

val nativeJars = platformLibraries.map { (classifier, libraries) ->
    tasks.register<Jar>("nativeJar_" + classifier.replace(Regex("[^A-Za-z0-9_]"), "_")) {
        description = "Assemble the $classifier native libraries jar"
        archiveClassifier = classifier
        from(libraries) {
            include(nativeLibraries.flatMap { listOf("lib$it.dylib", "lib$it.so") })
        }
        manifest {
            attributes("Implementation-Title" to "swiftkit-native", "Implementation-Version" to project.version)
            swiftVersion?.let { attributes("Swift-Version" to it) }
        }
    }
}

publishing.publications.named<MavenPublication>("maven") {
    nativeJars.forEach { artifact(it) }
}

// The main jar is empty and consumers must pick a classifier, which plain POM
// resolution handles directly. Gradle module metadata would only list the empty jar.
tasks.withType<GenerateModuleMetadata>().configureEach {
    enabled = false
}
