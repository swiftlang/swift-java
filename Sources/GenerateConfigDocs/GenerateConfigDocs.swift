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


import ArgumentParser
import Foundation

/// Regenerates swift-java.config documentation in  SwiftJavaConfigFile.md
/// straight from the doc comments on `SwiftJavaConfigurationShared.Configuration`.
///
/// Usage:
///   swift run generate-config-docs           regenerate the doc section in place
///   swift run generate-config-docs --check   exit 1 if the doc section is stale, without writing
@main
struct GenerateConfigDocs: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate-config-docs",
    abstract:
      "Regenerate the Supported Configuration Options section of SwiftJavaConfigFile.md from Configuration.swift."
  )

  @Flag(name: .long, help: "Exit non-zero if the doc section is stale, without writing.")
  var check: Bool = false

  func run() throws {
    let repoRoot = try Self.detectRepoRoot()

    let configFile =
      repoRoot
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent("SwiftJavaConfigurationShared", isDirectory: true)
      .appendingPathComponent("Configuration.swift", isDirectory: false)

    let docFile =
      repoRoot
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent("SwiftJavaDocumentation", isDirectory: true)
      .appendingPathComponent("Documentation.docc", isDirectory: true)
      .appendingPathComponent("SwiftJavaConfigFile.md", isDirectory: false)

    let scanDirs: [URL] = [
      repoRoot
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("SwiftJavaConfigurationShared", isDirectory: true),
      repoRoot
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("SwiftExtractConfigurationShared", isDirectory: true),
    ]

    // Parse enums and structs referenced by Configuration.
    let parsed = try ConfigParser.parse(rootDirs: scanDirs)

    // Parse the Configuration struct itself for its fields, sections, and effective<T> fallbacks.
    let configSource = try String(contentsOf: configFile, encoding: .utf8)
    let body = try ConfigurationBody.parse(source: configSource)

    // Render Markdown and splice into SwiftJavaConfigFile.md.
    let renderer = MarkdownRenderer(
      enums: parsed.enums,
      structs: parsed.structs,
      fields: body.fields,
      effectiveFallbacks: body.effectiveFallbacks
    )
    let generated = renderer.render()

    let docText = try String(contentsOf: docFile, encoding: .utf8)
    let newText = try MarkerSplicer.splice(into: docText, generated: generated)

    let relDoc = docFile.path.replacingOccurrences(of: repoRoot.path + "/", with: "")

    if newText == docText {
      print("\(relDoc) already up to date (\(body.fields.count) options documented)")
      return
    }

    if check {
      FileHandle.standardError.write(
        Data(
          """
          error: \(relDoc) is stale.
          Run 'swift run generate-config-docs' and commit the result.

          """.utf8
        )
      )
      throw ExitCode(1)
    }

    try newText.write(to: docFile, atomically: true, encoding: .utf8)
    print("Updated \(relDoc) (\(body.fields.count) options documented)")
  }

  /// Walk up from the executable's file location (this source file, at build
  /// time, and the invoking working directory otherwise) to find the repo root
  /// (identified by `Package.swift`).
  private static func detectRepoRoot() throws -> URL {
    // Start from the current working directory - `swift run` always chdir's to
    // the package root, which is exactly what we want.
    let fm = FileManager.default
    var dir = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
    for _ in 0..<20 {
      if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
        return dir
      }
      let parent = dir.deletingLastPathComponent()
      if parent.path == dir.path { break }
      dir = parent
    }
    throw ConfigDocsError(
      "Could not locate Package.swift from current directory \(fm.currentDirectoryPath)"
    )
  }
}
