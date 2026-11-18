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

/// Marker macro that controls whether jextract exports a Swift declaration to Java.
///
/// `@JavaExport` forces a declaration to be exported. When applied to a `typealias`,
/// it registers a specialization entry for generic types:
/// ```swift
/// @JavaExport public typealias FishTank = Tank<Fish>
/// ```
/// This tells jextract to generate a concrete `FishTank` Java class for `Tank<Fish>`,
/// even if `Tank` was included in the `filterExclude` configuration.
///
/// `@JavaExport(false)` keeps a declaration out of the Java bindings. On a type or an
/// extension, it also applies to their members and nested types:
/// ```swift
/// public struct Session {
///   public var token: String
///   @JavaExport(false) public var debugDump: [String: Any]
/// }
/// ```
///
/// With `"exportMode": "annotated"` in `swift-java.config`, jextract exports only declarations
/// marked `@JavaExport`, together with the members of a marked type or extension.
///
/// This module has no JNI dependency, so code that is also built for platforms
/// without Java can use the marker.
@attached(peer)
public macro JavaExport(_ isExported: Bool = true) =
  #externalMacro(module: "SwiftJavaMacros", type: "JavaExportMacro")
