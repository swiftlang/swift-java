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

import JExtractSwiftLib
import SwiftExtract
import SwiftJavaConfigurationShared
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

  /// Declarations the analyzer reports as skipped, here only because a type didn't resolve.
  private func skipped(_ source: String, _ exportMode: JExtractExportMode) throws -> [String] {
    final class Sink: SwiftExtractDiagnosticsSink {
      var names: [String] = []
      func emit(_ diagnostic: SwiftExtractDiagnostic) {
        names.append(diagnostic.declarationName)
      }
    }
    let config = config(exportMode)
    let sink = Sink()
    let analyzer = SwiftAnalyzer(
      config: config,
      extractDecider: JavaExtractDecider(exportMode: exportMode),
      diagnosticsSink: sink
    )
    try analyzer.analyze(path: "/fake/Fake.swiftinterface", text: source)
    return sink.names
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
}
