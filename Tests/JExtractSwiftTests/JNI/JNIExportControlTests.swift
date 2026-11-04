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

import CodePrinting
import JExtractSwiftLib
import SwiftExtract
import SwiftJavaConfigurationShared
import SwiftParser
import Testing

/// `@JavaExport(false)` opts declarations out, and `exportMode: annotated` exports only marked ones.
@Suite
struct JNIExportControlTests {
  let optOutSource =
    """
    public struct Session {
      public var token: String
      @JavaExport(false) public var secret: String
      @JavaExport(false) public func load(_ request: URLRequest) {}
      @JavaExport(false) public func pairs() -> [(Int64, String)] { [] }
    }
    @JavaExport(false)
    public struct Hidden {
      public func load(_ request: URLRequest) {}
    }
    @JavaExport(false)
    extension Session {
      public func fromExtension(_ request: URLRequest) {}
    }
    @JavaExport(false)
    extension UnknownType {
      public func helper() {}
    }
    """

  let annotatedSource =
    """
    @JavaExport
    public struct Exported {
      public var name: String
      @JavaExport(false) public var hidden: String
    }
    public struct Partial {
      @JavaExport public func picked() {}
      public func notPicked() {}
    }
    public struct Unmarked {
      public func load(_ request: URLRequest) {}
    }
    @JavaExport public func topLevel() {}
    public func notExported() {}
    extension UnknownType {
      public func helper() {}
    }
    """

  private func config(_ exportMode: JExtractExportMode) -> Configuration {
    var config = Configuration()
    config.swiftModule = "SwiftModule"
    config.exportMode = exportMode
    return config
  }

  /// Declarations the analyzer reports as skipped.
  private func skipped(_ source: String, _ exportMode: JExtractExportMode) throws -> [String] {
    try generate(source, exportMode).skipped
  }

  /// Generates the Java bindings, returning them and each skipped declaration with its reason.
  /// `dependencies` maps a dependency module's name to its source and export mode.
  private func generate(
    _ source: String,
    _ exportMode: JExtractExportMode,
    dependencies: [String: (source: String, exportMode: JExtractExportMode)] = [:]
  ) throws -> (java: String, skipped: [String]) {
    final class Sink: SwiftExtractDiagnosticsSink {
      var skipped: [String] = []
      func emit(_ diagnostic: SwiftExtractDiagnostic) {
        skipped.append("\(diagnostic.declarationName): \(diagnostic.message)")
      }
    }
    let config = config(exportMode)
    let sink = Sink()
    let analyzer = SwiftAnalyzer(
      config: config,
      extractDecider: JavaExtractDecider(
        exportMode: exportMode,
        swiftModuleName: config.swiftModule,
        dependencyExportModes: dependencies.mapValues(\.exportMode)
      ),
      diagnosticsSink: sink
    )
    for (name, dependency) in dependencies {
      let input = SwiftInputFile(syntax: Parser.parse(source: dependency.source), path: "/fake/\(name).swift")
      analyzer.sourceDependencies.swiftModuleInputs[name] = [input]
    }
    try analyzer.analyze(path: "/fake/Fake.swiftinterface", text: source)
    let generator = JNISwift2JavaGenerator(
      config: config,
      translator: analyzer,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake",
      javaClassLookupTable: [:],
      moduleJavaPackages: Dictionary(uniqueKeysWithValues: dependencies.keys.map { ($0, "com.example.\($0.lowercased())") })
    )
    var printer = JavaPrinter(mode: .accumulateAll)
    try generator.writeExportedJavaSources(&printer)
    return (printer.finalize(), sink.skipped)
  }

  @Test
  func optedOutDeclarationsAreNotExported() throws {
    try assertOutput(
      input: optOutSource,
      config: config(.all),
      .jni,
      .java,
      expectedChunks: [
        "public java.lang.String getToken()"
      ],
      notExpectedChunks: [
        "getSecret",
        "void load(",
        "pairs",
        "Hidden",
        "fromExtension",
      ]
    )
  }

  @Test
  func optedOutDeclarationsAreNotReportedAsSkipped() throws {
    let skipped = try skipped(optOutSource, .all)
    #expect(skipped.isEmpty, "\(skipped)")
    // Without the markers, the same declarations are reported.
    let unmarked = try self.skipped(optOutSource.replacingOccurrences(of: "@JavaExport(false)", with: ""), .all)
    #expect(unmarked.count == 4, "\(unmarked)")
  }

  @Test
  func annotatedModeExportsOnlyMarkedDeclarations() throws {
    try assertOutput(
      input: annotatedSource,
      config: config(.annotated),
      .jni,
      .java,
      expectedChunks: [
        "public java.lang.String getName()",
        "public void picked()",
        "public static void topLevel()",
      ],
      notExpectedChunks: [
        "getHidden",
        "notPicked",
        "Unmarked",
        "notExported",
        "void load(",
      ]
    )
  }

  @Test
  func unmarkedDeclarationsAreNotReportedAsSkipped() throws {
    let skipped = try skipped(annotatedSource, .annotated)
    #expect(skipped.isEmpty, "\(skipped)")
  }

  @Test
  func annotatedModeKeepsFoundationTypes() throws {
    let (java, skipped) = try generate(
      """
      import Foundation
      @JavaExport
      public struct Event {
        public var date: Date
        public var link: URL
      }
      """,
      .annotated
    )
    #expect(skipped.isEmpty, "\(skipped)")
    #expect(java.contains("public Date getDate(SwiftArena swiftArena)"), "\(java)")
    #expect(java.contains("public final class URL"), "\(java)")
  }

  @Test
  func declarationsUsingUnexportedTypesAreSkipped() throws {
    let (java, skipped) = try generate(
      """
      public struct Internal {}
      @JavaExport
      public struct Uses {
        public var name: String
        public var internal: Internal
        public func make() -> [Internal] { [] }
      }
      """,
      .annotated
    )
    #expect(java.contains("public java.lang.String getName()"), "\(java)")
    #expect(!java.contains("getInternal"), "\(java)")
    #expect(!java.contains("make("), "\(java)")
    #expect(skipped.contains { $0.hasPrefix("Uses.internal") && $0.contains("'Internal', which is not exported") }, "\(skipped)")
  }

  @Test
  func declarationsUsingUnexportedDependencyTypesAreSkipped() throws {
    let models = """
      public struct Cache {}
      @JavaExport
      public struct Item {}
      """
    let source = """
      import Models
      @JavaExport
      public struct Screen {
        public var item: Item
        public var cache: Cache
      }
      """
    let annotated = try generate(source, .annotated, dependencies: ["Models": (models, .annotated)])
    #expect(annotated.java.contains("getItem"), "\(annotated.java)")
    #expect(!annotated.java.contains("getCache"), "\(annotated.java)")
    #expect(annotated.skipped.contains { $0.contains("'Cache', which is not exported") }, "\(annotated.skipped)")

    // A dependency that exports everything exports `Cache` too.
    let all = try generate(source, .annotated, dependencies: ["Models": (models, .all)])
    #expect(all.java.contains("getCache"), "\(all.java)")
  }
}
