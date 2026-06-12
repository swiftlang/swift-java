//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import SwiftExtractConfigurationShared

/// The configuration surface required by the language-neutral `SwiftExtract`
/// analysis layer.
///
/// `SwiftExtract` deliberately does NOT depend on any language-specific
/// configuration module. Instead, each language layer makes its own
/// `Configuration` type conform to this protocol, mapping its settings onto the
/// neutral surface below. This keeps the analysis layer reusable across targets
/// (e.g. Java/JNI/FFM, or other language code generators) without pulling
/// target-specific config types into `SwiftExtract`.
///
/// `AccessLevelMode` lives in the small `SwiftExtractConfigurationShared`
/// target so language-specific configuration shared modules (e.g.
/// `SwiftJavaConfigurationShared`) can use the same enum directly without
/// taking a dependency on SwiftSyntax.
///
/// The enum-typed `swiftExtractLogLevel` member uses a `swiftExtract`-prefixed
/// name so a conforming type can keep its own, differently-typed `logLevel`
/// member without a name collision.
public protocol SwiftExtractConfiguration {
  /// Name of the Swift module being analyzed.
  var swiftModule: String? { get }

  /// Optional path to a JSON `StaticBuildConfiguration` used to resolve `#if`.
  var staticBuildConfigurationFile: String? { get }

  /// Glob patterns selecting which Swift files/types to extract.
  var swiftFilterInclude: [String]? { get }

  /// Glob patterns excluding Swift files/types from extraction.
  var swiftFilterExclude: [String]? { get }

  /// Stub declarations for imported modules whose source is unavailable to the
  /// analyzer. Keyed by module name; values are Swift declaration strings parsed
  /// as if they belonged to that module.
  var importedModuleStubs: [String: [String]]? { get }

  /// Minimum access level required for a declaration to be extracted.
  var swiftExtractAccessLevel: AccessLevelMode { get }

  /// Verbosity for the analyzer's logger; `nil` falls back to `.info`.
  var swiftExtractLogLevel: Logger.Level? { get }

  /// Whether to extract initializers of *generic* nominal types even when they
  /// are not (yet) specialized. swift-java skips these by default (an open
  /// generic isn't directly constructible); other language code generators that
  /// specialize generics in a post-analysis pass set this `true` so the base
  /// type's initializers are available to clone onto the specialization.
  /// Default: false.
  var extractsGenericTypeInitializers: Bool { get }

  /// Module names that should be treated as importable when resolving
  /// `#if canImport(<module>)` conditions, in addition to whatever the build
  /// configuration already knows. Lets a target opt-in to extracting code
  /// guarded behind `#if canImport(MyModule)` (e.g. another language code
  /// generator can declare its runtime module importable here). Default: empty.
  var availableImportModules: Set<String> { get }

  /// Whether type lookups that can't resolve a name should fall back to a
  /// synthetic, unresolved nominal reference instead of throwing
  /// `TypeTranslationError.unknown`.
  ///
  /// `SwiftExtract` defaults to a strict policy: when a parameter, return
  /// type, property type, etc. references a name the symbol table can't
  /// resolve, the enclosing declaration is silently dropped (the analyzer
  /// emits a `[warning] Failed to import: …` log line). That's correct for
  /// Java/JNI, where the generator can't render code referencing an
  /// unresolved Swift type.
  ///
  /// Other language code generators that treat unresolved names *symbolically*
  /// (e.g. associated types in a protocol requirement before carrier
  /// substitution; a property type that names a generic parameter to be
  /// replaced during specialization; an external type the user is expected
  /// to bridge by simple name) can opt-in by setting this `true`. Unresolved
  /// names then become synthetic nominal types via
  /// `SwiftSyntheticTypes.unresolvedNominal(_:)` so downstream passes can
  /// substitute or recognize them. Default: false.
  var permitsUnresolvedTypeReferences: Bool { get }

  /// Whether the given module name has stub declarations configured.
  func hasImportedModuleStub(moduleOfNominal moduleName: String) -> Bool
}

extension SwiftExtractConfiguration {
  public var availableImportModules: Set<String> { [] }

  public var permitsUnresolvedTypeReferences: Bool { false }

  public func hasImportedModuleStub(moduleOfNominal moduleName: String) -> Bool {
    importedModuleStubs?.keys.contains(moduleName) ?? false
  }
}

/// A minimal, self-contained `SwiftExtractConfiguration` for callers that only
/// need analysis (tests, tools) and don't have a richer language-specific
/// configuration to supply.
public struct DefaultSwiftExtractConfiguration: SwiftExtractConfiguration {
  public var swiftModule: String?
  public var staticBuildConfigurationFile: String?
  public var swiftFilterInclude: [String]?
  public var swiftFilterExclude: [String]?
  public var importedModuleStubs: [String: [String]]?
  public var swiftExtractAccessLevel: AccessLevelMode
  public var swiftExtractLogLevel: Logger.Level?
  public var extractsGenericTypeInitializers: Bool
  public var availableImportModules: Set<String>
  public var permitsUnresolvedTypeReferences: Bool

  public init(
    swiftModule: String? = nil,
    accessLevel: AccessLevelMode = .public,
    logLevel: Logger.Level? = nil,
    extractsGenericTypeInitializers: Bool = false,
    staticBuildConfigurationFile: String? = nil,
    swiftFilterInclude: [String]? = nil,
    swiftFilterExclude: [String]? = nil,
    importedModuleStubs: [String: [String]]? = nil,
    availableImportModules: Set<String> = [],
    permitsUnresolvedTypeReferences: Bool = false
  ) {
    self.swiftModule = swiftModule
    self.swiftExtractAccessLevel = accessLevel
    self.swiftExtractLogLevel = logLevel
    self.extractsGenericTypeInitializers = extractsGenericTypeInitializers
    self.staticBuildConfigurationFile = staticBuildConfigurationFile
    self.swiftFilterInclude = swiftFilterInclude
    self.swiftFilterExclude = swiftFilterExclude
    self.importedModuleStubs = importedModuleStubs
    self.availableImportModules = availableImportModules
    self.permitsUnresolvedTypeReferences = permitsUnresolvedTypeReferences
  }
}
