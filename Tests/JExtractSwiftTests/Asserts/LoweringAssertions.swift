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

@_spi(Testing) import JExtractSwift
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
  let translator = Swift2JavaTranslator(
    javaPackage: javaPackage,
    swiftModuleName: swiftModuleName
  )

  if let sourceFile {
    translator.add(filePath: "Fake.swift", text: sourceFile)
  }

  translator.prepareForTranslation()

  let swiftFunctionName: String
  let loweredFunction: LoweredFunctionSignature
  if let inputFunction = inputDecl.as(FunctionDeclSyntax.self) {
    loweredFunction = try translator.lowerFunctionSignature(
      inputFunction,
      enclosingType: enclosingType
    )
    swiftFunctionName = inputFunction.name.text
  } else if let inputInitializer = inputDecl.as(InitializerDeclSyntax.self) {
    loweredFunction = try translator.lowerFunctionSignature(
      inputInitializer,
      enclosingType: enclosingType
    )
    swiftFunctionName = "init"
  } else {
    fatalError("Unhandling declaration kind for lowering")
  }

  let loweredCDecl = loweredFunction.cdeclThunk(
    cName: "c_\(swiftFunctionName)",
    swiftFunctionName: swiftFunctionName,
    stdlibTypes: translator.swiftStdlibTypes
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

  let cFunction = translator.cdeclToCFunctionLowering(
    loweredFunction.cdecl,
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
