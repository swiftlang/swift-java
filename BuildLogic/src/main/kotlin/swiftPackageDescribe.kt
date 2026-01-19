import org.gradle.api.Project
import org.gradle.api.tasks.Exec
import org.gradle.kotlin.dsl.register
import org.gradle.kotlin.dsl.support.serviceOf
import org.gradle.process.ExecOperations
import utilities.SwiftcTargetInfo
import utilities.json
import utilities.swiftPMPackage
import java.io.ByteArrayOutputStream
import java.io.File

fun Project.swiftProductDylibPaths(swiftBuildConfiguration: String): List<String> {
    // TODO: require that we depend on swift-java
    // TODO: all the products where the targets depend on swift-java plugin
    return swiftPMPackage().targets.map {
        it.productMemberships
    }.flatten().map {
        logger.info("[swift-java] Include Swift product: '${it}' in product resource paths.")
        "${layout.projectDirectory}/.build/${swiftBuildConfiguration}/lib${it}.dylib"
    }
}

fun Project.registerCleanSwift(workingDir: File = layout.projectDirectory.asFile) {
    val cleanSwift = tasks.register<Exec>("cleanSwift") {
        this.workingDir = workingDir
        commandLine("swift")
        args("package", "clean")
    }
    tasks.named("clean").configure {
        dependsOn(cleanSwift)
    }
}

