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

/// Minimum access level a declaration must have to be considered for extraction.
///
/// Language-neutral counterpart to a configuration's access-level setting. The
/// concrete `Configuration` types in language layers (e.g. swift-java, or other
/// language code generators) map their own enums onto this.
public enum AccessLevelMode: String, Sendable {
  case `public`
  case `package`
  case `internal`
}

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
/// The two enum-typed members use `swiftExtract`-prefixed names so a conforming
/// type can keep its own, differently-typed `logLevel` /
/// `effectiveMinimumInputAccessLevelMode` members without a name collision.
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

  /// Whether operator declarations (e.g. `static func + (…)`) should be
  /// extracted as ordinary `.function`s. Most targets (e.g. Java) cannot express
  /// Swift operators and leave this `false`; other language code generators that
  /// map operators to language constructs set it `true` and recognize the
  /// operator functions in a post-analysis pass.
  var extractsOperators: Bool { get }

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

  /// Whether the given module name has stub declarations configured.
  func hasImportedModuleStub(moduleOfNominal moduleName: String) -> Bool
}

extension SwiftExtractConfiguration {
  public var extractsOperators: Bool { false }

  public var extractsGenericTypeInitializers: Bool { false }

  public var availableImportModules: Set<String> { [] }

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
  public var extractsOperators: Bool
  public var extractsGenericTypeInitializers: Bool
  public var availableImportModules: Set<String>

  public init(
    swiftModule: String? = nil,
    accessLevel: AccessLevelMode = .public,
    logLevel: Logger.Level? = nil,
    extractsOperators: Bool = false,
    extractsGenericTypeInitializers: Bool = false,
    staticBuildConfigurationFile: String? = nil,
    swiftFilterInclude: [String]? = nil,
    swiftFilterExclude: [String]? = nil,
    importedModuleStubs: [String: [String]]? = nil,
    availableImportModules: Set<String> = []
  ) {
    self.swiftModule = swiftModule
    self.swiftExtractAccessLevel = accessLevel
    self.swiftExtractLogLevel = logLevel
    self.extractsOperators = extractsOperators
    self.extractsGenericTypeInitializers = extractsGenericTypeInitializers
    self.staticBuildConfigurationFile = staticBuildConfigurationFile
    self.swiftFilterInclude = swiftFilterInclude
    self.swiftFilterExclude = swiftFilterExclude
    self.importedModuleStubs = importedModuleStubs
    self.availableImportModules = availableImportModules
  }
}
