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
    // AGP 9+ provides built-in Kotlin support, so the standalone
    // org.jetbrains.kotlin.android plugin must NOT be applied. The Compose
    // compiler plugin is still applied separately.
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.compiler)
}

repositories {
    google()
    mavenCentral()
    mavenLocal()
}

// API level the app targets at minimum. This value is substituted into the
// Swift target triples below (e.g. aarch64-unknown-linux-android28), so it must
// match an API level supported by the installed Swift Android SDK.
val androidMinSdk = 28

android {
    namespace = "com.example.swift.compose"
    compileSdk = 36

    defaultConfig {
        minSdk = androidMinSdk
        targetSdk = 36
        applicationId = "com.example.swift.compose"
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    implementation(project(":SwiftKitCore"))
    implementation(project(":SwiftKitCompose"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)
}

// ==== -----------------------------------------------------------------------
// MARK: Swift -> Android cross-compilation + jextract
//
// Mirrors swiftlang/swift-android-examples (hello-swift-java/hashing-lib). The
// Swift target carries the JExtractSwiftPlugin, so building it (even for an
// Android triple) also emits the generated Java sources as a side effect.

// Swift toolchain version passed to swiftly (e.g. "6.3"). Overridable via the
// SWIFT_VERSION environment variable for CI matrices.
val swiftVersion: String = System.getenv("SWIFT_VERSION") ?: "6.3"
// Android Swift SDK artifactbundle suffix; the bundle dir is
// "swift-${androidSdkVersion}.artifactbundle".
val androidSdkVersion: String = System.getenv("SWIFT_ANDROID_SDK_VERSION") ?: "$swiftVersion-RELEASE_android"
val sdkName = "swift-$androidSdkVersion.artifactbundle"

// Swift runtime libraries to bundle into jniLibs alongside the built product.
val swiftRuntimeLibs = listOf(
    "swiftCore", "swift_Concurrency", "swift_StringProcessing", "swift_RegexParser",
    "swift_Builtin_float", "swift_math", "swiftAndroid", "dispatch", "BlocksRuntime",
    "swiftSwiftOnoneSupport", "swiftDispatch", "Foundation", "FoundationEssentials",
    "FoundationInternationalization", "_FoundationICU", "swiftSynchronization",
    "swiftObservation",
)

// Android ABI -> Swift triple / swift-resources arch dir / NDK sysroot arch dir.
val abis: Map<String, Triple<String, String, String>> = mapOf(
    "arm64-v8a" to Triple("aarch64-unknown-linux-android$androidMinSdk", "swift-aarch64", "aarch64-linux-android"),
    "x86_64" to Triple("x86_64-unknown-linux-android$androidMinSdk", "swift-x86_64", "x86_64-linux-android"),
    "armeabi-v7a" to Triple("armv7-unknown-linux-android$androidMinSdk", "swift-armv7", "arm-linux-android"),
)

// Default to arm64-v8a only for a fast local loop; -PandroidAllAbis=true builds all.
val enableAllAbis = (project.findProperty("androidAllAbis") as String?)?.toBoolean() ?: false
val activeAbis = if (enableAllAbis) abis else abis.filterKeys { it == "arm64-v8a" }

val generatedJniLibsDir = layout.buildDirectory.dir("generated/jniLibs")

// Directory the JExtractSwiftPlugin writes generated Java into during `swift build`.
val generatedJavaDir = File(
    projectDir,
    ".build/plugins/outputs/${projectDir.name.lowercase()}/MySwiftLibrary/destination/JExtractSwiftPlugin/src/generated/java"
)

// These resolve lazily (inside task config blocks) so projects that have an
// Android SDK but not the Swift Android SDK / swiftly don't fail configuration.
fun findSwiftly(): String {
    (project.findProperty("swiftly.path") as String? ?: System.getenv("SWIFTLY_PATH"))?.let { return it }
    val home = System.getProperty("user.home")
    return listOf(
        "$home/.swiftly/bin/swiftly",
        "$home/.local/share/swiftly/bin/swiftly",
        "$home/.local/bin/swiftly",
        "/usr/local/bin/swiftly",
        "/opt/homebrew/bin/swiftly",
        "/root/.local/share/swiftly/bin/swiftly",
    ).firstOrNull { File(it).exists() }
        ?: throw GradleException("swiftly not found. Set -Pswiftly.path=<path> or the SWIFTLY_PATH environment variable.")
}

fun findSwiftSdkRoot(): String {
    (project.findProperty("swift.sdk.path") as String? ?: System.getenv("SWIFT_SDK_PATH"))?.let { return it }
    val home = System.getProperty("user.home")
    return listOf(
        "$home/Library/org.swift.swiftpm/swift-sdks",
        "$home/.config/swiftpm/swift-sdks",
        "$home/.swiftpm/swift-sdks",
        "/root/.swiftpm/swift-sdks",
    ).firstOrNull { File(it).isDirectory }
        ?: throw GradleException("Swift SDK path not found. Set -Pswift.sdk.path=<path> or the SWIFT_SDK_PATH environment variable.")
}

// Aggregator that also exposes the jextract-generated Java directory as an output.
// The directory itself is produced by the per-ABI `swift build` invocations.
val buildSwiftAll = tasks.register("buildSwiftAll") {
    group = "build"
    description = "Builds the Swift code for the active Android ABIs (and generates Java wrappers)."

    inputs.file(layout.projectDirectory.file("Package.swift"))
    inputs.dir(layout.projectDirectory.dir("Sources/MySwiftLibrary"))
    outputs.dir(generatedJavaDir)
}

activeAbis.forEach { (abi, info) ->
    val (triple, _, _) = info
    val task = tasks.register<Exec>("buildSwift${abi.replaceFirstChar { it.uppercase() }}") {
        group = "build"
        description = "Builds the Swift code for the $abi ABI ($triple)."

        outputs.dir(layout.projectDirectory.dir(".build/$triple/debug"))

        workingDir = projectDir
        executable = findSwiftly()
        args("run", "swift", "build", "+$swiftVersion", "--swift-sdk", triple, "--build-system", "native")

        doFirst { logger.lifecycle("Building Swift for $abi ($triple)…") }
    }
    buildSwiftAll.configure { dependsOn(task) }
}

val copyJniLibs = tasks.register<Copy>("copyJniLibs") {
    group = "build"
    description = "Collects the built Swift .so files + Swift runtime + libc++_shared.so into jniLibs."
    dependsOn(buildSwiftAll)

    val swiftSdkPath = "${findSwiftSdkRoot()}/$sdkName"

    activeAbis.forEach { (abi, info) ->
        val (triple, swiftArchDir, ndkDir) = info

        // Built products.
        from(layout.projectDirectory.dir(".build/$triple/debug")) {
            include("*.so")
            into(abi)
        }

        // C++ runtime from the NDK sysroot.
        from("$swiftSdkPath/swift-android/ndk-sysroot/usr/lib/$ndkDir/libc++_shared.so") {
            into(abi)
        }

        // Swift runtime libraries.
        from(swiftRuntimeLibs.map { "$swiftSdkPath/swift-android/swift-resources/usr/lib/$swiftArchDir/android/lib$it.so" }) {
            into(abi)
        }
    }

    into(generatedJniLibsDir)
}

android {
    sourceSets.getByName("main") {
        // jextract-generated Java sources (produced by buildSwiftAll's swift build).
        // AGP 9 rejects Provider/TaskProvider here, so we register the plain path
        // and rely on the preBuild -> copyJniLibs -> buildSwiftAll chain below to
        // generate the files before compilation.
        java.srcDir(generatedJavaDir)
        // Native libraries assembled by copyJniLibs.
        jniLibs.srcDir(generatedJniLibsDir.get().asFile)
    }
}

// Ensure native libs + generated sources exist before the Android build runs.
// preBuild is the per-variant anchor that compile tasks run after.
tasks.named("preBuild").configure {
    dependsOn(copyJniLibs)
}
