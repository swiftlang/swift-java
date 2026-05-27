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

public typealias SwiftModuleName = String
public typealias SwiftTypeName = String
public typealias SwiftSourceText = String

/// Holds inputs for symbol resolution that are not themselves the primary
/// extraction target: real Swift sources from dependency modules.
///
/// Dependency inputs are parsed once and registered as imported
/// `SwiftModuleSymbolTable`s so that cross-module type references in the
/// analysed module's API can resolve them.
public struct SourceDependencies {
  /// Parsed Swift inputs from dependency modules, keyed by Swift module name.
  public var swiftModuleInputs: [SwiftModuleName: [SwiftInputFile]] = [:]

  /// Synthetic stub inputs keyed by a synthetic module name (e.g. for
  /// generated `@JavaClass` placeholders). These are needed for symbol-table
  /// resolution but must NOT be emitted as `import <module>` statements in
  /// generated Swift code, because their names are not real Swift modules.
  public var syntheticStubInputs: [SwiftModuleName: [SwiftInputFile]] = [:]

  public init() {}

  /// Names of all dependency modules (real + synthetic) with associated Swift
  /// sources. Used by callers that need to resolve types belonging to either.
  public var swiftModuleNames: Set<SwiftModuleName> {
    Set(swiftModuleInputs.keys).union(syntheticStubInputs.keys)
  }

  /// Names of synthetic stub modules. These should be skipped at Swift import
  /// printing time.
  public var syntheticModuleNames: Set<SwiftModuleName> {
    Set(syntheticStubInputs.keys)
  }
}
