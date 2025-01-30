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
  sourceFile: SourceFileSyntax? = nil,
  enclosingType: TypeSyntax? = nil,
  expectedCDecl: DeclSyntax,
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
    translator.addSourceFile(sourceFile)
  }

  translator.prepareForTranslation()

  let inputFunction = inputDecl.cast(FunctionDeclSyntax.self)
  let loweredFunction = try translator.lowerFunctionSignature(
    inputFunction,
    enclosingType: enclosingType
  )
  let loweredCDecl = loweredFunction.cdeclThunk(cName: "c_\(inputFunction.name.text)", inputFunction: inputFunction)

  #expect(
    loweredCDecl.description == expectedCDecl.description,
    sourceLocation: Testing.SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  )
}
