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
import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

#if compiler(>=6.3)
private let `compiler(>=6.3)` = true
#else
private let `compiler(>=6.3)` = false
#endif

@Suite
struct IfConfigTests {
  @Test
  func evaluateIfConfigs() throws {
    try assertOutput(
      input: """
        #if os(Android)
        public func androidFunc()
        #else
        public func notAndroidFunc()
        #endif

        #if canImport(Foundation)
        public struct CanImport {
        }
        #else
        public struct CannotImport {
        }
        #endif

        #if DEBUG
        public struct IsDebug {
        }
        #else
        public struct IsNotDebug {
          #if os(Linux)
          public var linuxVar: Int
          #elseif os(iOS) || os(macOS)
          public var iOSorMacOSVar: Int
          #else
          #error("unsupported platform")
          #endif
        }
        #endif
        """,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static void androidFunc()",
        "public final class CannotImport",
        "public final class IsNotDebug",
        "public long getLinuxVar()",
      ],
      notExpectedChunks: [
        "public static void notAndroidFunc()",
        "public final class CanImport",
        "public final class IsDebug",
        "public long getIOSorMacOSVar() ",
      ]
    )
  }

  @Test
  func overrideWithStaticBuildConfigurationFile() throws {
    try withTemporaryFile(
      suffix: "json",
      contents: """
        {
          "attributes": [],
          "compilerVersion": {
            "components": [6, 3]
          },
          "customConditions": [
            "DEBUG"
          ],
          "endianness": "little",
          "features": [],
          "languageMode": {
            "components": [5, 10]
          },
          "targetArchitectures": [],
          "targetAtomicBitWidths": [],
          "targetEnvironments": [],
          "targetOSs": [],
          "targetObjectFileFormats": [],
          "targetPointerAuthenticationSchemes": [],
          "targetPointerBitWidth": 64,
          "targetRuntimes": []
        }
        """
    ) { staticBuildConfigFile in
      var config = Configuration()
      config.staticBuildConfigurationFile = staticBuildConfigFile.absoluteURL.path(percentEncoded: false)

      try assertOutput(
        input: """
          #if DEBUG
          public struct IsDebug {}
          #else
          public struct IsNotDebug {}
          #endif
          """,
        config: config,
        .ffm,
        .java,
        detectChunkByInitialLines: 1,
        expectedChunks: [
          "public final class IsDebug"
        ],
        notExpectedChunks: [
          "public final class IsNotDebug"
        ]
      )
    }
  }

  @Test(.enabled(if: `compiler(>=6.3)`))
  func swiftinterfaceCommonPattern() throws {
    try assertOutput(
      input: """
        public enum Foundation {
          public struct URL {}
        }

        public struct AppStore : Swift.Sendable, Swift.Codable {
          public var storeURL: Foundation.URL?
          #if compiler(>=5.3) && $NonescapableTypes
          public init(storeURL: Foundation.URL?)
          #endif
          public func encode(to encoder: any Swift.Encoder) throws
          public init(from decoder: any Swift.Decoder) throws
        }
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_AppStore__00024init__J")
        public func Java_com_example_swift_AppStore__00024init__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, storeURL: jlong) -> jlong
        """
      ]
    )
  }
}

private func withTemporaryFile(
  suffix: String,
  contents: String = "",
  in tempDirectory: URL = FileManager.default.temporaryDirectory,
  _ perform: (URL) throws -> Void
) throws {
  let tempFileName = "tmp_\(UUID().uuidString).\(suffix)"
  let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)

  try contents.write(to: tempFileURL, atomically: true, encoding: .utf8)
  defer {
    try? FileManager.default.removeItem(at: tempFileURL)
  }
  try perform(tempFileURL)
}
