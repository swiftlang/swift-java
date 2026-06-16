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

import SwiftExtract
import SwiftParser
import SwiftSyntax
import Testing

@Suite("SourceDependencies")
struct SourceDependenciesSuite {

  // ==== -----------------------------------------------------------------------
  // MARK: Real dependency module

  @Test func realDependencyModuleResolvesItsTypes() throws {
    var deps = SourceDependencies()
    deps.swiftModuleInputs["DepModule"] = [
      makeInputFile("public class DepClass {}", path: "Dep.swift")
    ]

    let symbolTable = makeSymbolTable(
      moduleName: "MyModule",
      sources: ["public func use(_ x: DepClass) {}"],
      sourceDependencies: deps
    )

    let dep = try #require(symbolTable.lookupTopLevelNominalType("DepClass"))
    #expect(dep.moduleName == "DepModule")
    #expect(dep.kind == .class)

    // Module-scoped lookup also works.
    let depViaModule = symbolTable.lookupTopLevelNominalType("DepClass", inModule: "DepModule")
    #expect(depViaModule === dep)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Synthetic stubs

  /// Verifies the fix that keeps `<javaClassStubs>` resolvable for type lookup
  /// while excluding it from anything that would emit `import <module>`.
  @Test func syntheticStubsAreResolvableButNotPrintable() throws {
    var deps = SourceDependencies()
    deps.syntheticStubInputs["<javaClassStubs>"] = [
      makeInputFile("@JavaClass public class JavaUtilFunction {}", path: "<javaClassStubs>.swift")
    ]

    let symbolTable = makeSymbolTable(
      moduleName: "MyModule",
      sources: ["public struct Anything {}"],
      sourceDependencies: deps
    )

    // The stub type is resolvable.
    let stub = try #require(symbolTable.lookupTopLevelNominalType("JavaUtilFunction"))
    #expect(stub.moduleName == "<javaClassStubs>")

    // The synthetic name is recorded as such.
    #expect(symbolTable.syntheticImportedModuleNames.contains("<javaClassStubs>"))

    // It must NOT be confused with a real module — `Swift` is not synthetic.
    #expect(!symbolTable.syntheticImportedModuleNames.contains("Swift"))
  }

  // ==== -----------------------------------------------------------------------
  // MARK: swiftModuleNames / syntheticModuleNames

  @Test func moduleNameSetsAreSeparateAndUnion() {
    var deps = SourceDependencies()
    deps.swiftModuleInputs["DepModule"] = [makeInputFile("public class A {}")]
    deps.syntheticStubInputs["<javaClassStubs>"] = [
      makeInputFile("@JavaClass public class B {}")
    ]

    #expect(deps.swiftModuleNames == Set(["DepModule", "<javaClassStubs>"]))
    #expect(deps.syntheticModuleNames == Set(["<javaClassStubs>"]))
  }

  @Test func mutatingOneFieldDoesNotAffectTheOther() {
    var deps = SourceDependencies()
    deps.swiftModuleInputs["DepModule"] = [makeInputFile("public class A {}")]
    #expect(deps.syntheticModuleNames.isEmpty)

    deps.syntheticStubInputs["<javaClassStubs>"] = [
      makeInputFile("@JavaClass public class B {}")
    ]
    #expect(deps.swiftModuleInputs.keys.contains("DepModule"))
    #expect(!deps.swiftModuleInputs.keys.contains("<javaClassStubs>"))
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Empty dependencies

  @Test func emptyDependenciesProduceUsableSymbolTable() throws {
    let symbolTable = makeSymbolTable(sources: ["public struct X {}"])

    // Built-in Swift module is still available even with no dependencies.
    #expect(symbolTable.lookupTopLevelNominalType("Int") != nil)

    // No synthetic modules.
    #expect(symbolTable.syntheticImportedModuleNames.isEmpty)
  }
}
