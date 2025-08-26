//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(Testing) import JExtractSwiftLib
import SwiftJavaConfigurationShared
import SwiftSyntax
import Testing

/// Assert that the lowering of the function function declaration to a @_cdecl
/// entrypoint matches the expected form.
func assertLoweredFunction(
  _ inputDecl: DeclSyntax,
  javaPackage: String = "org.swift.mypackage",
  swiftModuleName: String = "MyModule",
  sourceFile: String? = nil,
  enclosingType: TypeSyntax? = nil,
  expectedCDecl: DeclSyntax,
  expectedCFunction: String,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column
) throws {
  var config = Configuration()
  config.swiftModule = swiftModuleName
  let translator = Swift2JavaTranslator(config: config)

  if let sourceFile {
    translator.add(filePath: "Fake.swift", text: sourceFile)
  }

  translator.prepareForTranslation()

  let generator = FFMSwift2JavaGenerator(
    config: config,
    translator: translator,
    javaPackage: "com.example.swift",
    swiftOutputDirectory: "/fake",
    javaOutputDirectory: "/fake"
  )

  let swiftFunctionName: String
  let apiKind: SwiftAPIKind
  let loweredFunction: LoweredFunctionSignature
  if let inputFunction = inputDecl.as(FunctionDeclSyntax.self) {
    loweredFunction = try generator.lowerFunctionSignature(
      inputFunction,
      enclosingType: enclosingType
    )
    swiftFunctionName = inputFunction.name.text
    apiKind = .function
  } else if let inputInitializer = inputDecl.as(InitializerDeclSyntax.self) {
    loweredFunction = try generator.lowerFunctionSignature(
      inputInitializer,
      enclosingType: enclosingType
    )
    swiftFunctionName = "init"
    apiKind = .initializer
  } else {
    fatalError("Unhandling declaration kind for lowering")
  }

  let loweredCDecl = loweredFunction.cdeclThunk(
    cName: "c_\(swiftFunctionName)",
    swiftAPIName: swiftFunctionName,
    as: apiKind
  )

  #expect(
    loweredCDecl.description == expectedCDecl.description,
    sourceLocation: Testing.SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  )

  let cFunction = try loweredFunction.cFunctionDecl(
    cName: "c_\(swiftFunctionName)"
  )

  #expect(
    cFunction.description == expectedCFunction,
    sourceLocation: Testing.SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  )
}

/// Assert that the lowering of the function function declaration to a @_cdecl
/// entrypoint matches the expected form.
func assertLoweredVariableAccessor(
  _ inputDecl: VariableDeclSyntax,
  isSet: Bool,
  javaPackage: String = "org.swift.mypackage",
  swiftModuleName: String = "MyModule",
  sourceFile: String? = nil,
  enclosingType: TypeSyntax? = nil,
  expectedCDecl: DeclSyntax?,
  expectedCFunction: String?,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column
) throws {
  var config = Configuration()
  config.swiftModule = swiftModuleName
  let translator = Swift2JavaTranslator(config: config)

  if let sourceFile {
    translator.add(filePath: "Fake.swift", text: sourceFile)
  }

  translator.prepareForTranslation()

  let generator = FFMSwift2JavaGenerator(
    config: config,
    translator: translator,
    javaPackage: javaPackage,
    swiftOutputDirectory: "/fake",
    javaOutputDirectory: "/fake"
  )

  let swiftVariableName = inputDecl.bindings.first!.pattern.description
  let loweredFunction = try generator.lowerFunctionSignature(inputDecl, isSet: isSet, enclosingType: enclosingType)

  let loweredCDecl = loweredFunction?.cdeclThunk(
    cName: "c_\(swiftVariableName)",
    swiftAPIName: swiftVariableName,
    as: isSet ? .setter : .getter
  )

  #expect(
    loweredCDecl?.description == expectedCDecl?.description,
    sourceLocation: Testing.SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  )

  let cFunction = try loweredFunction?.cFunctionDecl(
    cName: "c_\(swiftVariableName)"
  )

  #expect(
    cFunction?.description == expectedCFunction,
    sourceLocation: Testing.SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  )
}
