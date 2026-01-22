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

package utilities

import kotlinx.serialization.Serializable
import org.gradle.api.Project
import org.gradle.kotlin.dsl.support.serviceOf
import org.gradle.process.ExecOperations
import java.io.ByteArrayOutputStream

@Serializable
internal data class SwiftPMPackage(
    val targets: List<SwiftPMTarget>,
)

internal fun Project.swiftPMPackage(): SwiftPMPackage {
    val stdout = ByteArrayOutputStream()
    serviceOf<ExecOperations>().exec {
        workingDir(projectDir)
        commandLine("swift", "package", "describe", "--type", "json")
        standardOutput = stdout
    }
    return json.decodeFromString<SwiftPMPackage>(stdout.toString())
}