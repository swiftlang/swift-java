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

import Foundation
import PackagePlugin

fileprivate let SwiftJavaConfigFileName = "swift-java.config"

@main
struct JExtractSwiftBuildToolPlugin: SwiftJavaPluginProtocol, BuildToolPlugin {

  var pluginName: String = "swift-java"
  var verbose: Bool = getEnvironmentBool("SWIFT_JAVA_VERBOSE")

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let toolURL = try context.tool(named: "SwiftJavaTool").url

    var commands: [Command] = []

    guard let sourceModule = target.sourceModule else { return [] }


    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    for dependency in target.dependencies {
      switch (dependency) {
      case .target(let t):
        t.sourceModule
      case .product(let p):
        p.sourceModules
      @unknown default:
        fatalError("Unknown target dependency type: \(dependency)")
      }
    }

    let sourceDir = target.directory.string

    // The name of the configuration file SwiftJava.config from the target for
    // which we are generating Swift wrappers for Java classes.
    let configFile = URL(filePath: sourceDir).appending(path: "swift-java.config")
    let configuration = try readConfiguration(sourceDir: "\(sourceDir)")

    // We use the the usual maven-style structure of "src/[generated|main|test]/java/..."
    // that is common in JVM ecosystem
    let outputJavaDirectory = context.outputJavaDirectory
    let outputSwiftDirectory = context.outputSwiftDirectory

    let dependentConfigFiles = searchForDependentConfigFiles(in: target)

    var arguments: [String] = [
      /*subcommand=*/"jextract",
      "--config", configFile.path(percentEncoded: false),
      "--swift-module", sourceModule.name,
      "--input-swift", sourceDir,
      "--output-java", outputJavaDirectory.path(percentEncoded: false),
      "--output-swift", outputSwiftDirectory.path(percentEncoded: false),
      // since SwiftPM requires all "expected" files do end up being written
      // and we don't know which files will have actual thunks generated... we force jextract to write even empty files.
      "--write-empty-files",
      // TODO: "--build-cache-directory", ...
      //       Since plugins cannot depend on libraries we cannot detect what the output files will be,
      //       as it depends on the contents of the input files. Therefore we have to implement this as a prebuild plugin.
      //       We'll have to make up some caching inside the tool so we don't re-parse files which have not changed etc.
    ]

    let dependentConfigFilesArguments = dependentConfigFiles.flatMap { moduleAndConfigFile in
      let (moduleName, configFile) = moduleAndConfigFile
      return [
        "--depends-on",
        "\(moduleName)=\(configFile.path(percentEncoded: false))"
      ]
    }
    arguments += dependentConfigFilesArguments

    let swiftFiles = sourceModule.sourceFiles.map { $0.url }.filter {
      $0.pathExtension == "swift"
    }

    // Output files are flattened filenames of the inputs, with the appended +SwiftJava suffix.
    var outputSwiftFiles: [URL] = swiftFiles.compactMap { sourceFileURL in
      guard sourceFileURL.isFileURL else {
        return nil as URL?
      }

      let sourceFilePath = sourceFileURL.path
      guard sourceFilePath.starts(with: sourceDir) else {
        fatalError("Could not get relative path for source file \(sourceFilePath)")
      }
      let outputURL = outputSwiftDirectory

      let inputFileName = sourceFileURL.deletingPathExtension().lastPathComponent
      return outputURL.appending(path: "\(inputFileName)+SwiftJava.swift")
    }

    // Append the "module file" that contains any thunks for global func definitions
    outputSwiftFiles += [
      outputSwiftDirectory.appending(path: "\(sourceModule.name)Module+SwiftJava.swift")
    ]

    // If the module uses 'Data' type, the thunk file is emitted as if 'Data' is declared
    // in that module. Declare the thunk file as the output.
    outputSwiftFiles += [
      outputSwiftDirectory.appending(path: "Foundation+SwiftJava.swift")
    ]

    print("[swift-java-plugin] Output swift files:\n - \(outputSwiftFiles.map({$0.absoluteString}).joined(separator: "\n - "))")

    var jextractOutputFiles = outputSwiftFiles

    // If the developer has enabled java callbacks in the configuration (default is false)
    // and we are running in JNI mode, we will run additional phases in this build plugin
    // to generate Swift wrappers using wrap-java that can be used to callback to Java.
    let shouldRunJavaCallbacksPhases = 
      if let configuration, 
         configuration.enableJavaCallbacks == true,
         configuration.effectiveMode == .jni {
        true
      } else {
        false
      }

    // Extract list of all sources
    let javaSourcesListFileName = "jextract-generated-sources.txt"
    let javaSourcesFile = outputJavaDirectory.appending(path: javaSourcesListFileName)
    if shouldRunJavaCallbacksPhases {
      arguments += [
        "--generated-java-sources-list-file-output", javaSourcesListFileName
      ]
      jextractOutputFiles += [javaSourcesFile]
    }

    commands += [
      .buildCommand(
        displayName: "Generate Java wrappers for Swift types",
        executable: toolURL,
        arguments: arguments,
        inputFiles: [ configFile ] + swiftFiles,
        outputFiles: jextractOutputFiles
      )
    ]

    // If we do not need Java callbacks, we can skip the remaining steps.
    guard shouldRunJavaCallbacksPhases else {
      return commands
    }

    // The URL of the compiled Java sources
    let javaCompiledClassesURL = context.pluginWorkDirectoryURL
      .appending(path: "compiled-java-output")

    // Build SwiftKitCore and get the classpath
    // as the jextracted sources will depend on that

    guard let swiftJavaDirectory = findSwiftJavaDirectory(for: target) else {
      fatalError("Unable to find the path to the swift-java sources, please file an issue.")
    }
    log("Found swift-java at \(swiftJavaDirectory)")

    let swiftKitCoreClassPath = swiftJavaDirectory.appending(path: "SwiftKitCore/build/classes/java/main")

    // We need to use a different gradle home, because
    // this plugin might be run from inside another gradle task
    // and that would cause conflicts.
    let gradleUserHome = context.pluginWorkDirectoryURL.appending(path: "gradle-user-home")

    let GradleUserHome = "GRADLE_USER_HOME"
    let gradleUserHomePath = gradleUserHome.path(percentEncoded: false)
    log("Prepare command: :SwiftKitCore:build in \(GradleUserHome)=\(gradleUserHomePath)")
    var gradlewEnvironment = ProcessInfo.processInfo.environment
    gradlewEnvironment[GradleUserHome] = gradleUserHomePath
    log("Forward environment: \(gradlewEnvironment)")

    let gradleExecutable = findExecutable(name: "gradle") ?? // try using installed 'gradle' if available in PATH
      swiftJavaDirectory.appending(path: "gradlew") // fallback to calling ./gradlew if gradle is not installed
    log("Detected 'gradle' executable (or gradlew fallback): \(gradleExecutable)")

    commands += [
      .buildCommand(
        displayName: "Build SwiftKitCore using Gradle (Java)",
        executable: gradleExecutable,
        arguments: [
          ":SwiftKitCore:build",
          "--project-dir", swiftJavaDirectory.path(percentEncoded: false),
          "--gradle-user-home", gradleUserHomePath, 
          "--configure-on-demand",
          "--no-daemon"
        ],
        environment: gradlewEnvironment,
        inputFiles: [swiftJavaDirectory],
        outputFiles: [swiftKitCoreClassPath]
      )
    ]

    // Compile the jextracted sources
    let javaHome = URL(filePath: findJavaHome())

    commands += [
      .buildCommand(
        displayName: "Build extracted Java sources",
        executable: javaHome
          .appending(path: "bin")
          .appending(path: self.javacName),
        arguments: [
          "@\(javaSourcesFile.path(percentEncoded: false))",
          "-d", javaCompiledClassesURL.path(percentEncoded: false),
          "-parameters",
          "-classpath", swiftKitCoreClassPath.path(percentEncoded: false)
        ],
        inputFiles: [javaSourcesFile, swiftKitCoreClassPath],
        outputFiles: [javaCompiledClassesURL]
      )
    ]

    // Run `configure` to extract a swift-java config to use for wrap-java
    let swiftJavaConfigURL = context.pluginWorkDirectoryURL.appending(path: "swift-java.config")

    commands += [
      .buildCommand(
        displayName: "Output swift-java.config that contains all extracted Java sources",
        executable: toolURL,
        arguments: [
          "configure",
          "--output-directory", context.pluginWorkDirectoryURL.path(percentEncoded: false),
          "--cp", javaCompiledClassesURL.path(percentEncoded: false),
          "--swift-module", sourceModule.name,
          "--swift-type-prefix", "Java"
        ],
        inputFiles: [javaCompiledClassesURL],
        outputFiles: [swiftJavaConfigURL]
      )
    ]

    let singleSwiftFileOutputName = "WrapJavaGenerated.swift"

    // In the end we can run wrap-java on the previous inputs
    var wrapJavaArguments = [
      "wrap-java",
      "--swift-module", sourceModule.name,
      "--output-directory", outputSwiftDirectory.path(percentEncoded: false),
      "--config", swiftJavaConfigURL.path(percentEncoded: false),
      "--cp", swiftKitCoreClassPath.path(percentEncoded: false),
      "--single-swift-file-output", singleSwiftFileOutputName
    ]

    // Add any dependent config files as arguments
    wrapJavaArguments += dependentConfigFilesArguments

    commands += [
      .buildCommand(
        displayName: "Wrap compiled Java sources using wrap-java",
        executable: toolURL,
        arguments: wrapJavaArguments,
        inputFiles: [swiftJavaConfigURL, swiftKitCoreClassPath],
        outputFiles: [outputSwiftDirectory.appending(path: singleSwiftFileOutputName)]
      )
    ]

    return commands
  }

  var javacName: String {
#if os(Windows)
    "javac.exe"
#else
    "javac"
#endif
  }

  /// Find the manifest files from other swift-java executions in any targets
  /// this target depends on.
  func searchForDependentConfigFiles(in target: any Target) -> [(String, URL)] {
    var dependentConfigFiles = [(String, URL)]()

    func _searchForConfigFiles(in target: any Target) {
      // log("Search for config files in target: \(target.name)")
      let dependencyURL = URL(filePath: target.directory.string)

      // Look for a config file within this target.
      let dependencyConfigURL = dependencyURL
        .appending(path: SwiftJavaConfigFileName)
      let dependencyConfigString = dependencyConfigURL
        .path(percentEncoded: false)

      if FileManager.default.fileExists(atPath: dependencyConfigString) {
        dependentConfigFiles.append((target.name, dependencyConfigURL))
      }
    }

    // Process direct dependencies of this target.
    for dependency in target.dependencies {
      switch dependency {
      case .target(let target):
        // log("Dependency target: \(target.name)")
        _searchForConfigFiles(in: target)

      case .product(let product):
        // log("Dependency product: \(product.name)")
        for target in product.targets {
          // log("Dependency product: \(product.name), target: \(target.name)")
          _searchForConfigFiles(in: target)
        }

      @unknown default:
        break
      }
    }

    // Process indirect target dependencies.
    for dependency in target.recursiveTargetDependencies {
      // log("Recursive dependency target: \(dependency.name)")
      _searchForConfigFiles(in: dependency)
    }

    return dependentConfigFiles
  }

  private func findSwiftJavaDirectory(for target: any Target) -> URL? {
    for dependency in target.dependencies {
      switch dependency {
      case .target(let target):
        continue

      case .product(let product):
        guard let swiftJava = product.sourceModules.first(where: { $0.name == "SwiftJava" }) else {
          continue
        }

        // We are inside Sources/SwiftJava
        return swiftJava.directoryURL.deletingLastPathComponent().deletingLastPathComponent()

      @unknown default:
        continue
      }
    }

    return nil
  }
}

func findExecutable(name: String) -> URL? {
  let fileManager = FileManager.default

  guard let path = ProcessInfo.processInfo.environment["PATH"] else {
    return nil
  }

  for path in path.split(separator: ":") {
    let fullURL = URL(fileURLWithPath: String(path)).appendingPathComponent(name)
    if fileManager.isExecutableFile(atPath: fullURL.path) {
      return fullURL
    }
  }

  return nil
}
