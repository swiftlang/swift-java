import DiscoverSwiftcAndLdArguments.Companion.DUMP_FILE_ARGS_SEPARATOR
import com.google.gson.Gson
import org.gradle.api.DefaultTask
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.FileSystemOperations
import org.gradle.api.file.RegularFile
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.ListProperty
import org.gradle.api.provider.Property
import org.gradle.api.provider.Provider
import org.gradle.api.provider.SetProperty
import org.gradle.api.tasks.IgnoreEmptyDirectories
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.JavaExec
import org.gradle.api.tasks.Nested
import org.gradle.api.tasks.Optional
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.OutputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.SourceSetContainer
import org.gradle.api.tasks.TaskAction
import org.gradle.api.tasks.testing.Test
import org.gradle.internal.extensions.core.serviceOf
import org.gradle.process.ExecOperations
import org.gradle.work.DisableCachingByDefault
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.swiftimport.SwiftImportExtension
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.swiftimport.SwiftPMDependency
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.Serializable
import javax.inject.Inject
import kotlin.collections.forEach
import kotlin.collections.joinToString
import kotlin.collections.plus

class SwiftPMImportPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        val project = target

        val swiftPMImportExtension = project.swiftPMDependenciesExtension()
        val importedModules = project.provider {
            swiftPMImportExtension.spmDependencies.flatMap { it.cinteropClangModules.map { it.name } }.toSet()
        }

        val computeLocalPackageDependencyInputFiles = project.registerTask<ComputeLocalPackageDependencyInputFiles>(
            ComputeLocalPackageDependencyInputFiles.TASK_NAME,
        ) {}

        val syntheticImportProjectGenerationTaskForSwiftcAndLdDumps = project.registerTask<GenerateSyntheticLinkageImportProject>(
            GenerateSyntheticLinkageImportProject.TASK_NAME,
        ) {
            it.configureWithExtension(swiftPMImportExtension)
            it.syntheticProductType.set(GenerateSyntheticLinkageImportProject.SyntheticProductType.DYNAMIC)
        }

        val fetchSyntheticImportProjectPackages = project.registerTask<FetchSyntheticImportProjectPackages>(
            FetchSyntheticImportProjectPackages.TASK_NAME,
        ) {
            it.dependsOn(syntheticImportProjectGenerationTaskForSwiftcAndLdDumps)
            it.syntheticImportProjectRoot.set(syntheticImportProjectGenerationTaskForSwiftcAndLdDumps.map { it.syntheticImportProjectRoot.get() })
        }

        val targetPlatform = "macOS"
        val targetSdk = "macosx"
        val archs = setOf(AppleArchitecture.ARM64)

        val swiftcAndLdDumpTask = project.registerTask<DiscoverSwiftcAndLdArguments>(
            "dumpSwiftcAndLdArgumentsFromImportedSwiftPMDependencies"
        ) {
            it.dependsOn(fetchSyntheticImportProjectPackages)
            it.dependsOn(computeLocalPackageDependencyInputFiles)
            it.buildScheme.set(SYNTHETIC_IMPORT_TARGET_MAGIC_NAME)
            it.aggregateModuleName.set(SYNTHETIC_IMPORT_TARGET_MAGIC_NAME)
            it.importedSwiftModules.set(importedModules)
            it.resolvedPackagesState.from(
                fetchSyntheticImportProjectPackages.map { it.inputManifests },
                fetchSyntheticImportProjectPackages.map { it.lockFile },
            )
            it.xcodebuildPlatform.set(targetPlatform)
            it.xcodebuildSdk.set(targetSdk)
            it.swiftPMDependenciesCheckout.set(fetchSyntheticImportProjectPackages.map { it.swiftPMDependenciesCheckout.get() })
            it.syntheticImportProjectRoot.set(syntheticImportProjectGenerationTaskForSwiftcAndLdDumps.map { it.syntheticImportProjectRoot.get() })
            it.filesToTrackFromLocalPackages.set(computeLocalPackageDependencyInputFiles.flatMap { it.filesToTrackFromLocalPackages })
            it.hasSwiftPMDependencies.set(project.provider { swiftPMImportExtension.spmDependencies.isNotEmpty() })
            it.architectures.set(archs)
        }

        val execOps = project.serviceOf<ExecOperations>()
        val swiftJavaRepoPath = swiftPMImportExtension.swiftJavaRepository.map { it.asFile }
        val buildSwiftJava = target.registerTask<BuildSwiftJava>("buildSwiftJava") {}

        val swiftJavaIntermediates = project.layout.buildDirectory.dir("swiftJavaIntermediates")

        val importedModuleToSourcesDump = importedModules.map { modules ->
            modules.map { module ->
                ImportedModuleInfo(
                    module,
                    swiftcAndLdDumpTask.get().moduleSwiftSources(archs.single(), module).get().asFile,
                    swiftJavaIntermediates.map { it.dir(module).dir("SwiftBridges") }.get().asFile,
                    swiftJavaIntermediates.map { it.dir(module).dir("JavaBridges") }.get().asFile,
                )
            }
        }

        val swiftJavaPath = buildSwiftJava.map { it.outputBinary() }

        val convertSwiftInterfacesIntoJavaSources = target.registerTask<DefaultTask>("convertImportedSwiftModulesIntoJavaSources") {
            it.dependsOn(buildSwiftJava)
            it.dependsOn(swiftcAndLdDumpTask)
            it.doLast {
                val swiftJavaPath = swiftJavaPath.get()
                val intermediates = swiftJavaIntermediates.get().asFile
                if (intermediates.exists()) { intermediates.deleteRecursively() }
                intermediates.mkdirs()

                importedModuleToSourcesDump.get().forEach { moduleInfo ->
                    execOps.exec {
                        it.commandLine(
                            swiftJavaPath,
                            "jextract",
                            "--swift-module", moduleInfo.moduleName,
                            "--java-package", "com.example.swift.${moduleInfo.moduleName}",
                            "--input-swift", moduleInfo.sourcesDump.readLines().first(),
                            "--output-swift", moduleInfo.swiftBridges,
                            "--output-java", moduleInfo.javaBridges,
                        )
                    }
                }
            }
        }

        val aggregateTargetName = GeneratePackageForBridgesCompilation.BRIDGES_COMPILATION_PROJECT_NAME
        val bridgesPackage = target.registerTask<GeneratePackageForBridgesCompilation>(GeneratePackageForBridgesCompilation.TASK_NAME) {
            it.dependsOn(convertSwiftInterfacesIntoJavaSources)
            it.configureWithExtension(swiftPMImportExtension)
            it.moduleInfos.set(importedModuleToSourcesDump)
            it.aggregateModuleName.set(aggregateTargetName)
            it.swiftcSearchPathsFile.set(swiftcAndLdDumpTask.map { it.swiftSearchPaths(archs.single()).getFile() })
            it.ldArgsFile.set(swiftcAndLdDumpTask.map { it.ldFilePath(archs.single()).getFile() })
        }

        val compileSwiftBridges = target.registerTask<DiscoverSwiftcAndLdArguments>("compileSwiftBridges") {
            it.dependsOn(bridgesPackage)
            it.buildScheme.set("${aggregateTargetName}-Package")
            it.aggregateModuleName.set(aggregateTargetName)
            it.xcodebuildPlatform.set(targetPlatform)
            it.xcodebuildSdk.set(targetSdk)
            it.filesToTrackFromLocalPackages.set(computeLocalPackageDependencyInputFiles.flatMap { it.filesToTrackFromLocalPackages })
            it.hasSwiftPMDependencies.set(project.provider { swiftPMImportExtension.spmDependencies.isNotEmpty() })
            it.importedSwiftModules.set(emptySet())
            it.swiftPMDependenciesCheckout.set(fetchSyntheticImportProjectPackages.map { it.swiftPMDependenciesCheckout.get() })
            it.syntheticImportProjectRoot.set(bridgesPackage.flatMap { it.syntheticImportProjectRoot })
            it.architectures.set(archs)
        }

        syntheticImportProjectGenerationTaskForSwiftcAndLdDumps.configure {
            it.directlyImportedSpmModules.set(swiftPMImportExtension.spmDependencies)
        }
        swiftPMImportExtension.spmDependencies.all { dependency ->
            when (dependency) {
                is SwiftPMDependency.Local -> {
                    computeLocalPackageDependencyInputFiles.configure {
                        it.localPackages.add(dependency.path)
                    }
                    fetchSyntheticImportProjectPackages.configure {
                        it.localPackageManifests.from(
                            dependency.path.resolve("Package.swift")
                        )
                    }
                }
                is SwiftPMDependency.Remote -> Unit
            }
        }

        target.pluginManager.withPlugin("java") {
            val sourceSets = target.extensions.getByName("sourceSets") as SourceSetContainer
            val mainSourceSet = sourceSets.getByName("main")
            mainSourceSet.java.srcDir(convertSwiftInterfacesIntoJavaSources.map {
                importedModuleToSourcesDump.get().map {
                    it.javaBridges
                }
            })

            val initialCompilationSearchPathFile = swiftcAndLdDumpTask.flatMap {
                it.librarySearchpathFilePath(archs.single())
            }
            val bridgesCompilationSearchPathFile = compileSwiftBridges.flatMap {
                it.librarySearchpathFilePath(archs.single())
            }

            fun intermediateSearchPaths(): List<String> {
                val initialCompilationSearchPath = initialCompilationSearchPathFile.getFile().readLines().first().split(DUMP_FILE_ARGS_SEPARATOR)
                val bridgesCompilationSearchPath = bridgesCompilationSearchPathFile.getFile().readLines().first().split(DUMP_FILE_ARGS_SEPARATOR)
                val intermediateSearchPaths = initialCompilationSearchPath + bridgesCompilationSearchPath
                return intermediateSearchPaths
            }

            fun computeLibraryPath(): String {
                val libraryPath = (listOf("/usr/lib/swift") + intermediateSearchPaths()).joinToString(":")
                return libraryPath
            }

            target.tasks.withType(JavaExec::class.java).configureEach {
                it.dependsOn(compileSwiftBridges)
                it.doFirst { task ->
                    task as JavaExec
                    task.jvmArgs("--enable-native-access=ALL-UNNAMED")
                    task.systemProperty("java.library.path", computeLibraryPath())
                    task.environment("DYLD_FALLBACK_LIBRARY_PATH", intermediateSearchPaths().joinToString(":"))
                }
            }

            target.tasks.withType(Test::class.java) {
                it.dependsOn(compileSwiftBridges)
                it.doFirst { task ->
                    task as Test
                    task.jvmArgs("--enable-native-access=ALL-UNNAMED")
                    task.systemProperty("java.library.path", computeLibraryPath())
                    task.environment("DYLD_FALLBACK_LIBRARY_PATH", intermediateSearchPaths().joinToString(":"))
                }
            }
        }
    }
}

internal inline fun <reified T: DefaultTask> Project.registerTask(name: String, crossinline configure: (T) -> Unit) =
    tasks.register(name, T::class.java) {
        configure(it)
    }

internal data class ImportedModuleInfo(
    @get:Input
    val moduleName: String,
    @get:Internal
    val sourcesDump: File,
    @get:PathSensitive(PathSensitivity.RELATIVE)
    @get:InputDirectory
    val swiftBridges: File,
    @get:PathSensitive(PathSensitivity.RELATIVE)
    @get:InputDirectory
    val javaBridges: File,
) : Serializable

internal fun Provider<RegularFile>.getFile() = get().asFile

internal fun Project.swiftPMDependenciesExtension(): SwiftImportExtension {
    val existingExtension = project.extensions.findByName(SwiftImportExtension.EXTENSION_NAME)
    if (existingExtension != null) {
        return existingExtension as SwiftImportExtension
    }
    project.extensions.create(
        SwiftImportExtension.EXTENSION_NAME,
        SwiftImportExtension::class.java
    )
    return project.extensions.getByName(SwiftImportExtension.EXTENSION_NAME) as SwiftImportExtension
}

@DisableCachingByDefault(because = "...")
internal abstract class BuildSwiftJava : DefaultTask() {

    @get:Internal
    val swiftJavaRepoPath = project.rootDir

    @get:InputFile
    protected val manifest get() = swiftJavaRepoPath.resolve("Package.swift")
    @get:InputFile
    protected val lockFile get() = swiftJavaRepoPath.resolve("Package.resolved")
    @get:InputDirectory
    protected val sources get() = swiftJavaRepoPath.resolve("Sources")

    @get:Inject
    protected abstract val execOps: ExecOperations

    @get:OutputFile
    val outputBinary get() = {
        val showBinPathOutput = ByteArrayOutputStream()
        execOps.exec {
            it.workingDir(swiftJavaRepoPath)
            it.commandLine("swift", "build", "--show-bin-path")
            it.standardOutput = showBinPathOutput
        }
        File(showBinPathOutput.toString().lineSequence().first()).resolve("swift-java")
    }

    @TaskAction
    fun build() {
        execOps.exec {
            it.workingDir(swiftJavaRepoPath)
            it.commandLine("swift", "build", "--product", "swift-java")
        }
    }

}

@DisableCachingByDefault(because = "...")
internal abstract class GenerateSyntheticLinkageImportProject : DefaultTask() {

    @get:Input
    abstract val directlyImportedSpmModules: SetProperty<SwiftPMDependency>

    @get:Internal
    val syntheticImportProjectRoot: DirectoryProperty = project.objects.directoryProperty().convention(
        project.layout.buildDirectory.dir("swiftJava/swiftImport")
    )

    @get:OutputFiles
    protected val projectRootTrackedFiles get() = syntheticImportProjectRoot.asFileTree.matching {
        it.exclude("Package.resolved")
    }

    @get:Optional
    @get:Input
    abstract val macosDeploymentVersion: Property<String>

    @get:Input
    abstract val syntheticProductType: Property<SyntheticProductType>

    enum class SyntheticProductType : Serializable {
        DYNAMIC,
        INFERRED,
    }

    fun configureWithExtension(swiftPMImportExtension: SwiftImportExtension) {
        macosDeploymentVersion.set(swiftPMImportExtension.macosDeploymentVersion)
    }

    @TaskAction
    fun generateSwiftPMSyntheticImportProjectAndFetchPackages() {
        val packageRoot = syntheticImportProjectRoot.get().asFile

        val forceAllLibrariesToBeDynamic = "forceAllLibrariesToBeDynamic"
        generatePackageManifest(
            identifier = SYNTHETIC_IMPORT_TARGET_MAGIC_NAME,
            packageRoot = packageRoot,
            syntheticProductType = syntheticProductType.get(),
            directlyImportedSwiftPMDependencies = directlyImportedSpmModules.get(),
            localSyntheticPackages = setOf(forceAllLibrariesToBeDynamic)
        )
        generatePackageManifest(
            identifier = forceAllLibrariesToBeDynamic,
            packageRoot = packageRoot.resolve(forceAllLibrariesToBeDynamic),
            syntheticProductType = SyntheticProductType.DYNAMIC,
            directlyImportedSwiftPMDependencies = directlyImportedSpmModules.get(),
            localSyntheticPackages = emptySet(),
        )
    }

    private fun generatePackageManifest(
        identifier: String,
        packageRoot: File,
        syntheticProductType: SyntheticProductType,
        directlyImportedSwiftPMDependencies: Set<SwiftPMDependency>,
        localSyntheticPackages: Set<String>,
    ) {
        val repoDependencies = directlyImportedSwiftPMDependencies.map { importedPackage ->
            buildString {
                appendLine(".package(")
                when (importedPackage) {
                    is SwiftPMDependency.Remote -> {
                        when (val repository = importedPackage.repository) {
                            is SwiftPMDependency.Remote.Repository.Id -> {
                                appendLine("  id: \"${repository.value}\",")
                            }
                            is SwiftPMDependency.Remote.Repository.Url -> {
                                appendLine("  url: \"${repository.value}\",")
                            }
                        }
                        when (val version = importedPackage.version) {
                            is SwiftPMDependency.Remote.Version.Exact -> appendLine("  exact: \"${version.value}\",")
                            is SwiftPMDependency.Remote.Version.From -> appendLine("  from: \"${version.value}\",")
                            is SwiftPMDependency.Remote.Version.Range -> appendLine("  \"${version.from}\"...\"${version.through}\",")
                            is SwiftPMDependency.Remote.Version.Branch -> appendLine("  branch: \"${version.value}\",")
                            is SwiftPMDependency.Remote.Version.Revision -> appendLine("  revision: \"${version.value}\",")
                        }
                    }
                    is SwiftPMDependency.Local -> {
                        appendLine("  path: \"${importedPackage.path.path}\",")
                    }
                }
                if (importedPackage.traits.isNotEmpty()) {
                    val traitsString = importedPackage.traits.joinToString(", ") { "\"${it}\"" }
                    appendLine("  traits: [${traitsString}],")
                }
                appendLine("),")
            }
        } + localSyntheticPackages.map {
            ".package(path: \"${it}\"),"
        }

        val targetDependencies = directlyImportedSwiftPMDependencies.flatMap { dep -> dep.products.map { it to dep.packageName } }.map {
            buildString {
                appendLine(".product(")
                appendLine("  name: \"${it.first.name}\",")
                appendLine("  package: \"${it.second}\",")
                val platformConstraints = it.first.platformConstraints
                if (platformConstraints != null) {
                    val platformsString = platformConstraints.joinToString(", ") { ".${it.swiftEnumName}" }
                    appendLine("  condition: .when(platforms: [${platformsString}]),")
                }
                appendLine("),")
            }
        } + localSyntheticPackages.map {
            ".product(name: \"${it}\", package: \"${it}\"),"
        }

        val platforms = listOf(".macOS(\"${macosDeploymentVersion.get()}\"),")

        val productType = when (syntheticProductType) {
            SyntheticProductType.DYNAMIC -> ".dynamic"
            SyntheticProductType.INFERRED -> ".none"
        }

        val manifest = packageRoot.resolve(MANIFEST_NAME)
        manifest.also {
            it.parentFile.mkdirs()
        }.writeText(
            buildString {
                appendLine("// swift-tools-version: 6.0")
                appendLine("import PackageDescription")
                appendLine("let package = Package(")
                appendLine("  name: \"$identifier\",")
                appendLine("  platforms: [")
                platforms.forEach { appendLine("    $it")}
                appendLine("  ],")
                appendLine(
                    """
                        products: [
                            .library(
                                name: "$identifier",
                                type: ${productType},
                                targets: ["$identifier"]
                            ),
                        ],
                    """.replaceIndent("  ")
                )
                appendLine("  dependencies: [")
                repoDependencies.forEach { appendLine(it.replaceIndent("    ")) }
                appendLine("  ],")
                appendLine("  targets: [")
                appendLine("    .target(")
                appendLine("      name: \"$identifier\",")
                appendLine("      dependencies: [")
                targetDependencies.forEach { appendLine(it.replaceIndent("        ")) }
                appendLine("      ],")
                appendLine("    ),")
                appendLine("  ]")
                appendLine(")")
            }
        )

        val swiftSource = "Sources/${identifier}/${identifier}.swift"
        // Generate swift sources specifically because the next SWIFT_EXEC-overriding step relies on passing a swiftc shim to dump compiler arguments
        packageRoot.resolve(swiftSource).also {
            it.parentFile.mkdirs()
        }.writeText("")
    }

    companion object {
        const val TASK_NAME = "generateSyntheticLinkageSwiftPMImportProject"
        const val SYNTHETIC_IMPORT_TARGET_MAGIC_NAME = "_internal_linkage_SwiftPMImport"
        const val MANIFEST_NAME = "Package.swift"
    }
}

@DisableCachingByDefault(because = "...")
internal abstract class GeneratePackageForBridgesCompilation : DefaultTask() {

    @get:Nested
    abstract val moduleInfos: ListProperty<ImportedModuleInfo>

    @get:InputFile
    abstract val swiftcSearchPathsFile: Property<File>

    @get:InputFile
    abstract val ldArgsFile: Property<File>

    @get:Internal
    val syntheticImportProjectRoot: DirectoryProperty = project.objects.directoryProperty().convention(
        project.layout.buildDirectory.dir("swiftJava/swiftImportBridgesCompilation")
    )

    @get:Input
    abstract val aggregateModuleName: Property<String>

    @get:Optional
    @get:Input
    abstract val macosDeploymentVersion: Property<String>

    @get:OutputFile
    protected val manifest get() = syntheticImportProjectRoot.asFile.get().resolve("Package.swift")
    @get:OutputDirectory
    protected val sources get() = syntheticImportProjectRoot.asFile.get().resolve("Sources")

    @get:Inject
    protected abstract val fsOps: FileSystemOperations

    fun configureWithExtension(swiftPMImportExtension: SwiftImportExtension) {
        macosDeploymentVersion.set(swiftPMImportExtension.macosDeploymentVersion)
    }

    @TaskAction
    fun generatePackageForBridgesCompilation() {
        val packageRoot = syntheticImportProjectRoot.get().asFile

        val platforms = listOf(".macOS(\"${macosDeploymentVersion.get()}\"),")
        val linkerSettingsShim = "_linkerSettingsShim"

        val targets = mutableListOf<String>()
        val products = mutableListOf<String>()
        val swiftcSearchPaths = swiftcSearchPathsFile.get()
            .readLines().first().split(DUMP_FILE_ARGS_SEPARATOR).joinToString(", ") { "\"${it}\"" }
        val ldArgs = ldArgsFile.get()
            .readLines().first().split(DUMP_FILE_ARGS_SEPARATOR).joinToString(", ") { "\"${it}\"" }
        val bridgeModules = mutableSetOf<String>()
        targets.add(
            """
               .target(
                    name: "${linkerSettingsShim}",
                    linkerSettings: [.unsafeFlags([${ldArgs}])]
               ), 
            """.trimIndent()
        )

        moduleInfos.get().forEach {
            val bridgeName = "${it.moduleName}_Bridges"
            targets.add(
                """
                    .target(
                        name: "${bridgeName}",
                        dependencies: ["${linkerSettingsShim}"],
                        swiftSettings: [
                            .swiftLanguageMode(.v5),
                            .unsafeFlags([${swiftcSearchPaths}])
                        ],
                    ),
                """.trimIndent()
            )
            products.add(
                """
                    .library(
                        name: "${bridgeName}",
                        type: .dynamic,
                        targets: ["${bridgeName}"]
                    ),
                """.trimIndent()
            )
            bridgeModules.add(bridgeName)
        }

        val dependenciesString = (bridgeModules + listOf(linkerSettingsShim)).joinToString(", ") { "\"${it}\"" }
        targets.add(
            """
                .target(
                    name: "${aggregateModuleName.get()}",
                    dependencies: [${dependenciesString}]
                ),
            """.trimIndent()
        )
        products.add(
            """
                .library(
                    name: "${aggregateModuleName.get()}",
                    type: .dynamic,
                    targets: ["${aggregateModuleName.get()}"]
                ),
            """.trimIndent()
        )

        val manifest = packageRoot.resolve(MANIFEST_NAME)
        manifest.also {
            it.parentFile.mkdirs()
        }.writeText(
            buildString {
                appendLine("// swift-tools-version: 6.0")
                appendLine("import PackageDescription")
                appendLine("let package = Package(")
                appendLine("  name: \"$BRIDGES_COMPILATION_PROJECT_NAME\",")
                appendLine("  platforms: [")
                platforms.forEach { appendLine("    $it")}
                appendLine("  ],")
                appendLine("  products: [")
                products.forEach { appendLine("    $it")}
                appendLine("  ],")
                appendLine("  targets: [")
                targets.forEach { appendLine("    $it") }
                appendLine("  ]")
                appendLine(")")
            }
        )

        moduleInfos.get().forEach { module ->
            val swiftSource = "Sources/${module.moduleName}_Bridges"
            val bridgePath = packageRoot.resolve(swiftSource).also {
                it.parentFile.mkdirs()
            }
            fsOps.sync {
                it.from(module.swiftBridges)
                it.into(bridgePath)
            }
        }
        listOf(
            aggregateModuleName.get(),
            linkerSettingsShim
        ).forEach {
            packageRoot.resolve("Sources/${it}/${it}.swift").also {
                it.parentFile.mkdirs()
            }.writeText("")
        }
    }

    companion object {
        const val TASK_NAME = "generateSwiftBridgesCompilationPackage"
        const val BRIDGES_COMPILATION_PROJECT_NAME = "SwiftBridgesCompilation"
        const val MANIFEST_NAME = "Package.swift"
    }
}

@DisableCachingByDefault(because = "...")
internal abstract class FetchSyntheticImportProjectPackages : DefaultTask() {

    /**
     * Refetch when Package manifests of local SwiftPM dependencies change
     */
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val localPackageManifests: ConfigurableFileCollection

    @get:Internal
    val syntheticImportProjectRoot: DirectoryProperty = project.objects.directoryProperty()

    /**
     * These are own manifest and manifests from project/modular dependencies. Refetch when any of these Package manifests changed.
     */
    @get:IgnoreEmptyDirectories
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    val inputManifests
        get() = syntheticImportProjectRoot
            .asFileTree
            .matching {
                it.include("**/Package.swift")
            }

    @get:Internal
    val swiftPMDependenciesCheckout: DirectoryProperty = project.objects.directoryProperty().convention(
        project.layout.buildDirectory.dir("swiftJava/swiftPMCheckout")
    )

    /**
     * Invalidate fetch when Package.swift or Package.resolved files changed.
     */
    @get:OutputFile
    val lockFile = syntheticImportProjectRoot.file("Package.resolved")

    @get:Internal
    protected val swiftPMDependenciesCheckoutLogs: DirectoryProperty = project.objects.directoryProperty().convention(
        project.layout.buildDirectory.dir("swiftJava/swiftPMCheckoutDD")
    )

    @get:Inject
    protected abstract val execOps: ExecOperations

    @TaskAction
    fun generateSwiftPMSyntheticImportProjectAndFetchPackages() {
        checkoutSwiftPMDependencies()
    }

    private fun checkoutSwiftPMDependencies() {
        execOps.exec {
            it.workingDir(syntheticImportProjectRoot.get().asFile)
            it.commandLine(
                "xcodebuild", "-resolvePackageDependencies",
                "-scheme", SYNTHETIC_IMPORT_TARGET_MAGIC_NAME,
                XCODEBUILD_SWIFTPM_CHECKOUT_PATH_PARAMETER, swiftPMDependenciesCheckout.get().asFile.path,
                "-derivedDataPath", swiftPMDependenciesCheckoutLogs.get().asFile.path,
            )
        }
    }

    companion object {
        const val TASK_NAME = "fetchSyntheticImportProjectPackages"
    }
}

@DisableCachingByDefault(because = "...")
internal abstract class DiscoverSwiftcAndLdArguments : DefaultTask() {
    @get:Input
    abstract val buildScheme: Property<String>

    @get:Input
    abstract val aggregateModuleName: Property<String>

    @get:Input
    abstract val xcodebuildPlatform: Property<String>
    @get:Input
    abstract val xcodebuildSdk: Property<String>

    @get:Input
    abstract val architectures: SetProperty<AppleArchitecture>

    @get:Input
    abstract val hasSwiftPMDependencies: Property<Boolean>

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val filesToTrackFromLocalPackages: RegularFileProperty
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    protected val localPackageSources get() = filesToTrackFromLocalPackages.map { it.asFile.readLines().filter { it.isNotEmpty() }.map { File(it) } }

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val resolvedPackagesState: ConfigurableFileCollection

    private val layout = project.layout

    @get:OutputDirectory
    protected val swiftDump = xcodebuildSdk.flatMap { sdk ->
        layout.buildDirectory.dir("swiftJava/${buildScheme.get()}/swiftImportSwiftDump/${sdk}")
    }

    @get:OutputDirectory
    protected val ldDump = xcodebuildSdk.flatMap { sdk ->
        layout.buildDirectory.dir("swiftJava/${buildScheme.get()}/swiftImportLdDump/${sdk}")
    }

    @get:Internal
    abstract val swiftPMDependenciesCheckout: DirectoryProperty

    @get:Internal
    abstract val syntheticImportProjectRoot: DirectoryProperty
    @get:InputFile
    protected val manifest get() = syntheticImportProjectRoot.asFile.get().resolve("Package.swift")
    @get:InputDirectory
    protected val sources get() = syntheticImportProjectRoot.asFile.get().resolve("Sources")


    @get:Internal
    val syntheticImportDd get() = layout.buildDirectory.dir("swiftJava/${buildScheme.get()}/swiftImportDd")

    @get:Input
    abstract val importedSwiftModules: SetProperty<String>

    @get:Inject
    protected abstract val execOps: ExecOperations

    @TaskAction
    fun generateDefFiles() {
        if (!hasSwiftPMDependencies.get()) {
            architectures.get().forEach { architecture ->
                // moduleSwiftSources(architecture).getFile().writeText("\n")
                ldFilePath(architecture).getFile().writeText("\n")
                librarySearchpathFilePath(architecture).getFile().writeText("\n")
            }
            return
        }

        val dumpIntermediates = xcodebuildSdk.flatMap { sdk ->
            layout.buildDirectory.dir("swiftJava/swiftImportDump/${sdk}")
        }.get().asFile.also {
            if (it.exists()) {
                it.deleteRecursively()
            }
            it.mkdirs()
        }

        val swiftcPathOutput = ByteArrayOutputStream()
        execOps.exec {
            it.commandLine("xcrun", "-f", "swiftc")
            it.standardOutput = swiftcPathOutput
        }
        val swiftArgsDumpScript = dumpIntermediates.resolve("swiftc")
        val swiftcPath = File(swiftcPathOutput.toString().lineSequence().first())
        // Otherwise SwiftPM dependencies build explodes due to missing features
        val compilerFeatures = swiftcPath.parentFile.parentFile.resolve("share/swift/features.json")
        val compilerFeaturesCopy = swiftArgsDumpScript.parentFile.parentFile.resolve("share/swift/features.json")
        compilerFeaturesCopy.parentFile.mkdirs()
        compilerFeatures.copyTo(compilerFeaturesCopy, overwrite = true)
        swiftArgsDumpScript.writeText(swiftcArgsDumpScript())
        swiftArgsDumpScript.setExecutable(true)
        val swiftArgsDump = dumpIntermediates.resolve("swift_args_dump")
        swiftArgsDump.mkdirs()

        val ldArgsDumpScript = dumpIntermediates.resolve("ldDump.sh")
        ldArgsDumpScript.writeText(ldArgsDumpScript())
        ldArgsDumpScript.setExecutable(true)
        val ldArgsDump = dumpIntermediates.resolve("ld_args_dump")
        ldArgsDump.mkdirs()

        val targetArchitectures = architectures.get().map {
            it.xcodebuildArch
        }

        val projectRoot = syntheticImportProjectRoot.get().asFile
        val dd = syntheticImportDd.get().asFile.resolve("dd_${xcodebuildSdk.get()}")

        execOps.exec { exec ->
            exec.workingDir(projectRoot)
            exec.commandLine(
                "xcodebuild", "clean", "build",
                "-scheme",
                buildScheme.get(),
                "-destination", "generic/platform=${xcodebuildPlatform.get()}",
                "-derivedDataPath", dd.path,
                XCODEBUILD_SWIFTPM_CHECKOUT_PATH_PARAMETER, swiftPMDependenciesCheckout.get().asFile.path,
                "SWIFT_EXEC=${swiftArgsDumpScript.path}",
                "LD=${ldArgsDumpScript.path}",
                "ARCHS=${targetArchitectures.joinToString(" ")}",
                "CODE_SIGN_IDENTITY=-",
                "COMPILER_INDEX_STORE_ENABLE=NO",
                "SWIFT_INDEX_STORE_ENABLE=NO",
                "SWIFT_USE_INTEGRATED_DRIVER=NO",
                // "SWIFT_EMIT_MODULE_INTERFACE=YES", ended up not being useful
                "-IDEPackageSupportCreateDylibsForDynamicProducts=YES",
            )
            exec.environment(KOTLIN_SWIFTC_ARGS_DUMP_FILE_ENV, swiftArgsDump)
            exec.environment(KOTLIN_LD_ARGS_DUMP_FILE_ENV, ldArgsDump)
        }

        val importedSwiftModules = importedSwiftModules.get()

        architectures.get().forEach { architecture ->
            val clangArchitecture = architecture.clangArch
            val swiftSourceFiles = mutableMapOf<String, String>()
            val swiftSearchPaths = mutableListOf<String>()

            val javaHome = File(System.getProperty("java.home"))
            swiftSearchPaths.add("-I${javaHome.resolve("include").path}")
            swiftSearchPaths.add("-I${javaHome.resolve("include/darwin").path}")

            swiftArgsDump.listFiles().filter {
                it.isFile
            }.forEach {
                val swiftcArgs = it.readLines().single()
                val isCompilationSwiftcCall = "-target${DUMP_FILE_ARGS_SEPARATOR}${clangArchitecture}-apple" in swiftcArgs
                        && "-module-name" in swiftcArgs
                if (isCompilationSwiftcCall) {
                    val splitArgs = swiftcArgs.split(DUMP_FILE_ARGS_SEPARATOR)
                    val moduleName = splitArgs[splitArgs.indexOf("-module-name") + 1]
                    if (moduleName in importedSwiftModules) {
                        val sourcesPath = splitArgs.first { it.startsWith("@") && it.endsWith(".SwiftFileList") }.substring(1)
                        swiftSourceFiles[moduleName] = File(sourcesPath).readLines().joinToString(",")
                    }
                    if (moduleName == aggregateModuleName.get()) {
                        val takePlusOne = setOf("-I", "-F", "-Isystem", "-Xcc")
                        splitArgs.forEachIndexed { index, arg ->
                            if (arg in takePlusOne) {
                                swiftSearchPaths.add(arg)
                                swiftSearchPaths.add(splitArgs[index + 1])
                            } else if (arg.startsWith("-I")) {
                                swiftSearchPaths.add(arg)
                            }
                        }
                    }
                }
            }

            swiftSourceFiles.forEach { moduleName, sourcesPaths ->
                val swiftSourcesPath = moduleSwiftSources(architecture, moduleName)
                swiftSourcesPath.getFile().writeText(sourcesPaths)
            }
            val swiftSearchPathsFile = swiftSearchPaths(architecture)
            swiftSearchPathsFile.getFile().writeText(swiftSearchPaths.joinToString(DUMP_FILE_ARGS_SEPARATOR))

            val architectureSpecificProductLdCalls = ldArgsDump.listFiles().filter {
                it.isFile
            }.filter {
                // This will actually be a clang call
                val ldArgs = it.readLines().single()
                ("@rpath/lib${aggregateModuleName.get()}.dylib" in ldArgs || "@rpath/${aggregateModuleName.get()}.framework" in ldArgs)
                        && "-target${DUMP_FILE_ARGS_SEPARATOR}${clangArchitecture}-apple" in ldArgs
            }
            val architectureSpecificProductLdCall = architectureSpecificProductLdCalls.single()
            val ldArgs = mutableListOf<String>()
            val resplitLdCall = architectureSpecificProductLdCall.readLines().single().split(DUMP_FILE_ARGS_SEPARATOR)
            val linkTimeFrameworkSearchPaths = mutableSetOf<String>()
            val librarySearchPaths = mutableSetOf<String>()

            resplitLdCall.forEachIndexed { index, arg ->
                if (arg == "-filelist" || arg == "-framework" || (arg.startsWith("-") && arg.endsWith("_framework"))) {
                    ldArgs.addAll(listOf(arg, resplitLdCall[index + 1]))
                }
                if (arg.startsWith("-l")) {
                    ldArgs.add(arg)
                }
                if (arg.startsWith("-F/")) {
                    ldArgs.add(arg)
                    linkTimeFrameworkSearchPaths.add(arg.substring(2))
                }
                if (arg.startsWith("-L/")) {
                    ldArgs.add(arg)
                    librarySearchPaths.add(arg.substring(2))
                }
                if (arg.startsWith("/")) {
                    if (arg.endsWith(".a")) {
                        ldArgs.add(arg)
                    }
                    if (arg.endsWith(".dylib")) {
                        ldArgs.add(arg)
                        librarySearchPaths.add((File(arg).parentFile.path))
                    }
                    if (".framework/" in arg) {
                        ldArgs.add(arg)
                        linkTimeFrameworkSearchPaths.add(
                            File(arg).parentFile.parentFile.path
                        )
                    }
                }
            }

            ldFilePath(architecture).getFile()
                .writeText(ldArgs.joinToString(DUMP_FILE_ARGS_SEPARATOR))
            librarySearchpathFilePath(architecture).getFile()
                .writeText(librarySearchPaths.joinToString(DUMP_FILE_ARGS_SEPARATOR))
        }
    }

    fun moduleSwiftSources(architecture: AppleArchitecture, moduleName: String) = swiftDump.map { it.file("${architecture.xcodebuildArch}_${moduleName}_swift_sources") }
    fun swiftSearchPaths(architecture: AppleArchitecture) = swiftDump.map { it.file("${architecture.xcodebuildArch}_swift_search_paths") }
    fun ldFilePath(architecture: AppleArchitecture) = ldDump.map { it.file("${architecture.xcodebuildArch}.ld") }
    fun librarySearchpathFilePath(architecture: AppleArchitecture) = ldDump.map { it.file("${architecture.xcodebuildArch}_library_search_paths") }

    private fun swiftcArgsDumpScript() = argsDumpScript("swiftc", KOTLIN_SWIFTC_ARGS_DUMP_FILE_ENV)
    private fun ldArgsDumpScript() = argsDumpScript("clang", KOTLIN_LD_ARGS_DUMP_FILE_ENV)

    private fun argsDumpScript(
        targetCli: String,
        dumpPathEnv: String,
    ) = """
        #!/bin/bash

        DUMP_FILE="${'$'}{${dumpPathEnv}}/${'$'}(/usr/bin/uuidgen)"
        for arg in "$@"
        do
           echo -n "${'$'}arg" >> "${'$'}{DUMP_FILE}"
           echo -n "$DUMP_FILE_ARGS_SEPARATOR" >> "${'$'}{DUMP_FILE}"
        done

        ${targetCli} "$@"
    """.trimIndent()

    companion object Companion {
        const val KOTLIN_SWIFTC_ARGS_DUMP_FILE_ENV = "KOTLIN_SWIFTC_ARGS_DUMP_FILE"
        const val KOTLIN_LD_ARGS_DUMP_FILE_ENV = "KOTLIN_LD_ARGS_DUMP_FILE"
        const val DUMP_FILE_ARGS_SEPARATOR = ";"
    }

}

@DisableCachingByDefault(because = "...")
internal abstract class ComputeLocalPackageDependencyInputFiles : DefaultTask() {

    @get:Input
    val localPackages: SetProperty<File> = project.objects.setProperty(File::class.java)

    /**
     * Recompute if the manifests change
     */
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    protected val manifests get() = localPackages.map { it.map { it.resolve("Package.swift") } }

    @get:OutputFile
    val filesToTrackFromLocalPackages: RegularFileProperty = project.objects.fileProperty().convention(
        project.layout.buildDirectory.file("swiftJava/swiftImportFilesToTrackFromLocalPackages")
    )

    @get:Inject
    protected abstract val execOps: ExecOperations

    @TaskAction
    fun generateSwiftPMSyntheticImportProjectAndFetchPackages() {
        val localPackageFiles = localPackages.get().flatMap { packageRoot ->
            listOf(
                packageRoot.resolve("Package.swift")
            ) + findLocalPackageSources(packageRoot)
        }.map {
            it.path
        }
        filesToTrackFromLocalPackages.getFile().writeText(
            localPackageFiles.joinToString("\n")
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun findLocalPackageSources(path: File): List<File> {
        val jsonBuffer = ByteArrayOutputStream()
        execOps.exec { exec ->
            exec.workingDir(path)
            exec.standardOutput = jsonBuffer
            exec.commandLine("swift", "package", "describe", "--type", "json")
            exec.environment.keys.filter {
                // Swift CLIs try to compile the manifest for iphonesimulator... with these envs
                it.startsWith("SDK")
            }.forEach {
                exec.environment.remove(it)
            }
        }
        val packageJson = Gson().fromJson(
            jsonBuffer.toString(), Map::class.java
        ) as Map<String, Any>
        val targets = packageJson["targets"] as List<Map<String, Any>>
        val relativeSourceRootPaths = targets
            .filter {
                val moduleType = it["module_type"]
                moduleType == "SwiftTarget" || moduleType == "ClangTarget"
            }
            .map {
                it["path"] as String
            }
        return relativeSourceRootPaths.map {
            path.resolve(it)
        }
    }

    companion object {
        const val TASK_NAME = "computeLocalPackageDependencyInputFiles"
    }
}


internal enum class AppleArchitecture : Serializable {
    ARM64,
    X86_64,
    ARMV7K,
    ARM64_32;

    val xcodebuildArch get() = clangArch
    val clangArch
        get() = when (this) {
            ARM64 -> "arm64"
            X86_64 -> "x86_64"
            ARMV7K -> "armv7k"
            ARM64_32 -> "arm64_32"
        }
}

internal const val XCODEBUILD_SWIFTPM_CHECKOUT_PATH_PARAMETER = "-clonedSourcePackagesDirPath"
internal const val SYNTHETIC_IMPORT_TARGET_MAGIC_NAME = "_internal_linkage_SwiftPMImport"