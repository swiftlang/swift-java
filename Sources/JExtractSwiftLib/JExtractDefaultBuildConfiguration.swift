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
import SwiftSyntax
import SwiftIfConfig

/// A default, fixed build configuration during static analysis for interface extraction.
struct JExtractDefaultBuildConfiguration: BuildConfiguration {
  private var base: StaticBuildConfiguration

  init() {
    let decoder = JSONDecoder()
    base = try! decoder.decode(StaticBuildConfiguration.self, from: printStaticBuildConfigOutput)
  }

  func isCustomConditionSet(name: String) throws -> Bool {
    base.isCustomConditionSet(name: name)
  }

  func hasFeature(name: String) throws -> Bool {
    base.hasFeature(name: name)
  }

  func hasAttribute(name: String) throws -> Bool {
    base.hasAttribute(name: name)
  }

  func canImport(importPath: [(TokenSyntax, String)], version: CanImportVersion) throws -> Bool {
    try base.canImport(importPath: importPath, version: version)
  }

  func isActiveTargetOS(name: String) throws -> Bool {
    true
  }

  func isActiveTargetArchitecture(name: String) throws -> Bool {
    true
  }

  func isActiveTargetEnvironment(name: String) throws -> Bool {
    true
  }

  func isActiveTargetRuntime(name: String) throws -> Bool {
    true
  }

  func isActiveTargetPointerAuthentication(name: String) throws -> Bool {
    true
  }

  func isActiveTargetObjectFormat(name: String) throws -> Bool {
    true
  }

  var targetPointerBitWidth: Int {
    base.targetPointerBitWidth
  }

  var targetAtomicBitWidths: [Int] {
    base.targetAtomicBitWidths
  }

  var endianness: Endianness {
    base.endianness
  }

  var languageVersion: VersionTuple {
    base.languageVersion
  }

  var compilerVersion: VersionTuple {
    base.compilerVersion
  }
}

fileprivate let shared = JExtractDefaultBuildConfiguration()

extension BuildConfiguration where Self == JExtractDefaultBuildConfiguration {
  static var jextractDefault: JExtractDefaultBuildConfiguration {
    shared
  }
}

// $ swift frontend -print-static-build-config -target aarch64-unknown-linux-gnu
fileprivate let printStaticBuildConfigOutput = Data(#"{"attributes":["GKInspectable","noDerivative","objcMembers","discardableResult","const","available","usableFromInline","preconcurrency","nonisolated","retroactive","frozen","unsafe","propertyWrapper","lifetime","_extern","inline","abi","storageRestrictions","_opaqueReturnTypeOf","objc","constInitialized","autoclosure","escaping","unchecked","requires_stored_property_inits","convention","attached","nonexhaustive","dynamicCallable","reasync","dynamicMemberLookup","NSCopying","transpose","warn_unqualified_access","c","globalActor","isolated","_local","rethrows","exclusivity","backDeployed","UIApplicationMain","main","nonobjc","resultBuilder","Sendable","_noMetadata","IBDesignable","IBOutlet","export","IBSegueAction","IBAction","derivative","NSApplicationMain","inlinable","concurrent","IBInspectable","NSManaged","_addressable","differentiable"],"compilerVersion":{"components":[6,3]},"customConditions":[],"endianness":"little","features":["BuiltinCreateAsyncTaskWithExecutor","BuiltinCreateAsyncTaskName","Macros","ValueGenericsNameLookup","FreestandingExpressionMacros","AssociatedTypeAvailability","NoncopyableGenerics2","BuiltinInterleave","OptionalIsolatedParameters","BuiltinAddressOfRawLayout","InoutLifetimeDependence","ExtensionMacros","BuiltinBuildMainExecutor","BuiltinStoreRaw","InheritActorContext","IsolatedAny","BuiltinExecutor","LayoutPrespecialization","NonexhaustiveAttribute","InlineAlways","BuiltinCreateTaskGroupWithFlags","ValueGenerics","InlineArrayTypeSugar","BuiltinCreateTask","NonescapableTypes","RetroactiveAttribute","BuiltinTaskRunInline","BuiltinBuildComplexEqualityExecutor","MemorySafetyAttributes","BuiltinBuildExecutor","ModuleSelector","ParameterPacks","MarkerProtocol","ConformanceSuppression","BitwiseCopyable","AddressOfProperty2","UnsafeInheritExecutor","BuiltinCreateAsyncTaskOwnedTaskExecutor","SpecializeAttributeWithAvailability","BuiltinJob","AlwaysInheritActorContext","AsyncExecutionBehaviorAttributes","AsyncSequenceFailure","BorrowingSwitch","PrimaryAssociatedTypes2","NewCxxMethodSafetyHeuristics","ExtensionMacroAttr","BuiltinStackAlloc","TypedThrows","BuiltinContinuation","BuiltinUnprotectedAddressOf","BuiltinSelect","ImplicitSelfCapture","MoveOnlyPartialConsumption","Actors","GeneralizedIsSameMetaTypeBuiltin","MoveOnly","GlobalActors","BuiltinCreateAsyncDiscardingTaskInGroupWithExecutor","NonfrozenEnumExhaustivity","RethrowsProtocol","IsolatedDeinit","BuiltinUnprotectedStackAlloc","BuiltinCreateAsyncTaskInGroupWithExecutor","BuiltinTaskGroupWithArgument","NoAsyncAvailability","ObjCImplementation","AttachedMacros","FreestandingMacros","AsyncAwait","EffectfulProp","BuiltinConcurrencyStackNesting","BuiltinCreateAsyncTaskInGroup","ConcurrentFunctions","BuiltinHopToActor","BuiltinIntLiteralAccessors","BodyMacros","BuiltinVectorsExternC","BuiltinCreateAsyncDiscardingTaskInGroup","RawIdentifiers","NonescapableAccessorOnTrivial","UnavailableFromAsync","IsolatedAny2","LexicalLifetimes","SendableCompletionHandlers","BuiltinAssumeAlignment","AssociatedTypeImplements","Sendable","ABIAttributeSE0479","BuiltinBuildTaskExecutorRef","LifetimeDependenceMutableAccessors","BitwiseCopyable2","IsolatedConformances","ExpressionMacroDefaultArguments","NoncopyableGenerics","SendingArgsAndResults","MoveOnlyResilientTypes","BuiltinEmplaceTypedThrows"],"languageMode":{"components":[5,10]},"targetArchitectures":["arm64"],"targetAtomicBitWidths":[128,64,32,16,8],"targetEnvironments":[],"targetOSs":["Linux"],"targetObjectFileFormats":["ELF"],"targetPointerAuthenticationSchemes":["_none"],"targetPointerBitWidth":64,"targetRuntimes":["_Native","_multithreaded"]}"#.utf8)
