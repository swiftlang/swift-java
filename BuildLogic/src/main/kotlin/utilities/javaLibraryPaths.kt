package utilities

import org.gradle.api.Project
import org.gradle.kotlin.dsl.support.serviceOf
import org.gradle.process.ExecOperations
import java.io.ByteArrayOutputStream
import java.io.File

private fun Project.swiftRuntimeLibraryPaths(): List<String> {
    val stdout = ByteArrayOutputStream()
    serviceOf<ExecOperations>().exec {
        workingDir(projectDir)
        commandLine("swiftc", "-print-target-info")
        standardOutput = stdout
    }
    return json.decodeFromString<SwiftcTargetInfo>(stdout.toString()).paths.runtimeLibraryPaths
}

fun Project.javaLibraryPaths(rootDir: File?): List<String> {
    val osName = System.getProperty("os.name")
    val osArch = System.getProperty("os.arch")
    val isLinux = osName.lowercase().contains("linux")
    val base = if (rootDir == null) "" else "${rootDir}/"

    val triple = if (isLinux) {
        val arch = if (osArch == "amd64" || osArch == "x86_64") "x86_64" else osArch
        "${arch}-unknown-linux-gnu"
    } else {
        val arch = if (osArch == "aarch64") "arm64" else osArch
        "${arch}-apple-macosx"
    }

    val paths: List<String> = listOf("release", "debug").flatMap { configuration ->
        listOf(
            "${base}.build/${triple}/$configuration/",
            "${base}../../.build/${triple}/$configuration/",
        )
    }
    val swiftRuntimePaths = swiftRuntimeLibraryPaths()

    return paths + swiftRuntimePaths
}