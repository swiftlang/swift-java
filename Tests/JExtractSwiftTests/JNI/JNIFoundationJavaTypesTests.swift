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
import SwiftJavaConfigurationShared
import Testing

/// With `foundationTypesAsJavaTypes`, Foundation values cross as standard Java types.
@Suite
struct JNIFoundationJavaTypesTests {
  let source =
    """
    import Foundation

    public struct Profile {
      public var homepage: URL
      public var avatar: URL?
      public var joined: Date
      public var photo: Data
      public var locale: Locale
      public var timeZone: TimeZone
      public var scale: CGFloat
      public var links: [URL]

      public func visit(_ body: (URL, Date) -> Void) {}
    }
    """

  var config: Configuration {
    var config = Configuration()
    config.mode = .jni
    config.foundationTypesAsJavaTypes = true
    return config
  }

  @Test
  func javaBindings() throws {
    try assertOutput(
      input: source,
      config: config,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "private static native java.net.URI $getHomepage(long selfPointer);",
        "public void setAvatar(Optional<java.net.URI> newValue) {",
        "private static native void $setAvatar(byte newValue_discriminator, java.net.URI newValue_value, long selfPointer);",
        "private static native java.util.Date $getJoined(long selfPointer);",
        "private static native byte[] $getPhoto(long selfPointer);",
        "private static native java.util.Locale $getLocale(long selfPointer);",
        "private static native java.util.TimeZone $getTimeZone(long selfPointer);",
        "private static native double $getScale(long selfPointer);",
        "private static native java.net.URI[] $getLinks(long selfPointer);",
        "void apply(java.net.URI _0, java.util.Date _1);",
      ],
      notExpectedChunks: [
        "class URL",
        "class Date",
        "class Data",
      ]
    )
  }

  @Test
  func swiftThunks() throws {
    try assertOutput(
      input: source,
      config: config,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "selfPointer$.pointee.homepage = URL(fromJNI: newValue, in: environment)",
        "selfPointer$.pointee.avatar = newValue_discriminator == 1 ? URL(fromJNI: newValue_value, in: environment) : nil",
        "selfPointer$.pointee.photo = Data(fromJNI: newValue, in: environment)",
        "selfPointer$.pointee.scale = CGFloat(newValue$indirect)",
        "return Double(selfPointer$.pointee.scale).getJNILocalRefValue(in: environment)",
      ]
    )
  }

  @Test
  func cgFloatIsDoubleWithoutTheOption() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "private static native double $getScale(long selfPointer);"
      ]
    )
  }
}
