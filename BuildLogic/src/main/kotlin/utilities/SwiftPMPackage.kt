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