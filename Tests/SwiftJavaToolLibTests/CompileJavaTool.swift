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

import Foundation
import Subprocess

@testable import SwiftJavaToolLib

/// Utility for compiling Java source files using javac in tests.
struct CompileJavaTool {

  /// Compiles multiple Java source files together, supporting different packages.
  ///
  /// - Parameter sourceFiles: A dictionary mapping relative file paths
  ///   (e.g. `"androidx/annotation/RequiresApi.java"`) to their source text.
  /// - Returns: The directory containing compiled `.class` files (the classpath root).
  static func compileJavaMultiFile(_ sourceFiles: [String: String]) async throws -> Foundation.URL {
    let baseDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-testing-\(UUID().uuidString)")
    let srcDir = baseDir.appendingPathComponent("src")
    let classesDir = baseDir.appendingPathComponent("classes")

    try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: classesDir, withIntermediateDirectories: true)

    var filePaths: [String] = []
    for (relativePath, source) in sourceFiles {
      let fileURL = srcDir.appendingPathComponent(relativePath)
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try source.write(to: fileURL, atomically: true, encoding: .utf8)
      filePaths.append(fileURL.path)
    }

    var javacArguments: [String] = ["-d", classesDir.path]
    javacArguments.append(contentsOf: filePaths)

    let javacProcess = try await Subprocess.run(
      .path(.init("\(javaHome)" + "/bin/javac")),
      arguments: .init(javacArguments),
      output: .string(limit: Int.max, encoding: UTF8.self),
      error: .string(limit: Int.max, encoding: UTF8.self)
    )

    guard javacProcess.terminationStatus.isSuccess else {
      let outString = javacProcess.standardOutput ?? ""
      let errString = javacProcess.standardError ?? ""
      fatalError(
        "javac failed (\(javacProcess.terminationStatus));\nOUT: \(outString)\nERROR: \(errString)"
      )
    }

    print("Compiled java sources to: \(classesDir)")
    return classesDir
  }

  /// Compiles a single Java source file.
  ///
  /// - Parameter sourceText: The Java source code.
  /// - Returns: The directory containing compiled `.class` files (the classpath root).
  static func compileJava(_ sourceText: String) async throws -> Foundation.URL {
    // Java requires public class files to be named after the class
    let sourceFile: Foundation.URL
    if let match = sourceText.range(of: #"public\s+class\s+(\w+)"#, options: .regularExpression) {
      let classNameRange = sourceText[match]
      let className = classNameRange.split(separator: " ").last.map(String.init) ?? "tmp_\(UUID().uuidString)"
      let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("swift-java-src-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      sourceFile = dir.appendingPathComponent("\(className).java")
      try sourceText.write(to: sourceFile, atomically: true, encoding: .utf8)
    } else {
      sourceFile = try TempFile.create(suffix: "java", sourceText)
    }

    let classesDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-testing-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: classesDir, withIntermediateDirectories: true)

    let javacProcess = try await Subprocess.run(
      .path(.init("\(javaHome)" + "/bin/javac")),
      arguments: [
        "-d", classesDir.path,
        sourceFile.path,
      ],
      output: .string(limit: Int.max, encoding: UTF8.self),
      error: .string(limit: Int.max, encoding: UTF8.self)
    )

    guard javacProcess.terminationStatus.isSuccess else {
      let outString = javacProcess.standardOutput ?? ""
      let errString = javacProcess.standardError ?? ""
      fatalError(
        "javac '\(sourceFile)' failed (\(javacProcess.terminationStatus));\nOUT: \(outString)\nERROR: \(errString)"
      )
    }

    print("Compiled java sources to: \(classesDir)")
    return classesDir
  }

  /// Packages a classes directory into a JAR file.
  ///
  /// - Parameter classesDir: The directory containing compiled `.class` files.
  /// - Returns: The URL of the created JAR file.
  static func makeJar(classesDir: Foundation.URL) async throws -> Foundation.URL {
    let jarFile = classesDir.deletingLastPathComponent()
      .appendingPathComponent("test-\(UUID().uuidString).jar")

    let jarProcess = try await Subprocess.run(
      .path(.init("\(javaHome)" + "/bin/jar")),
      arguments: ["cf", jarFile.path, "-C", classesDir.path, "."],
      output: .string(limit: Int.max, encoding: UTF8.self),
      error: .string(limit: Int.max, encoding: UTF8.self)
    )

    guard jarProcess.terminationStatus.isSuccess else {
      let outString = jarProcess.standardOutput ?? ""
      let errString = jarProcess.standardError ?? ""
      fatalError(
        "jar failed (\(jarProcess.terminationStatus));\nOUT: \(outString)\nERROR: \(errString)"
      )
    }

    print("Created JAR: \(jarFile)")
    return jarFile
  }
}
