//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension JNISwift2JavaGenerator {
  func writeSwiftThunkSources() throws {
    var printer = CodePrinter()
    try writeSwiftThunkSources(&printer)
  }

  package func writeSwiftExpectedEmptySources() throws {
    for expectedFileName in self.expectedOutputSwiftFiles {
      logger.trace("Write empty file: \(expectedFileName) ...")

      var printer = CodePrinter()
      printer.print("// Empty file generated on purpose")
      _ = try printer.writeContents(
        outputDirectory: self.swiftOutputDirectory,
        javaPackagePath: nil,
        filename: expectedFileName)
    }
  }

  package func writeSwiftThunkSources(_ printer: inout CodePrinter) throws {
    let moduleFilenameBase = "\(self.swiftModuleName)Module+SwiftJava"
    let moduleFilename = "\(moduleFilenameBase).swift"

    do {
      logger.trace("Printing swift module class: \(moduleFilename)")

      try printGlobalSwiftThunkSources(&printer)

      if let outputFile = try printer.writeContents(
        outputDirectory: self.swiftOutputDirectory,
        javaPackagePath: nil,
        filename: moduleFilename
      ) {
        print("[swift-java] Generated: \(moduleFilenameBase.bold).swift (at \(outputFile))")
        self.expectedOutputSwiftFiles.remove(moduleFilename)
      }

      for (_, ty) in self.analysis.importedTypes.sorted(by: { (lhs, rhs) in lhs.key < rhs.key }) {
        let fileNameBase = "\(ty.swiftNominal.qualifiedName)+SwiftJava"
        let filename = "\(fileNameBase).swift"
        logger.info("Printing contents: \(filename)")

        do {
          try printNominalTypeThunks(&printer, ty)

          if let outputFile = try printer.writeContents(
            outputDirectory: self.swiftOutputDirectory,
            javaPackagePath: nil,
            filename: filename) {
            print("[swift-java] Generated: \(fileNameBase.bold).swift (at \(outputFile))")
            self.expectedOutputSwiftFiles.remove(filename)
          }
        } catch {
          logger.warning("Failed to write to Swift thunks: \(filename)")
        }
      }
    } catch {
      logger.warning("Failed to write to Swift thunks: \(moduleFilename)")
    }
  }

  private func printGlobalSwiftThunkSources(_ printer: inout CodePrinter) throws {
    printHeader(&printer)

    for decl in analysis.importedGlobalFuncs {
      printSwiftFunctionThunk(&printer, decl)
      printer.println()
    }

    for decl in analysis.importedGlobalVariables {
      printSwiftFunctionThunk(&printer, decl)
      printer.println()
    }
  }

  private func printNominalTypeThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) throws {
    printHeader(&printer)

    for initializer in type.initializers {
      printInitializerThunk(&printer, initializer)
      printer.println()
    }

    for method in type.methods {
      printSwiftFunctionThunk(&printer, method)
      printer.println()
    }

    for variable in type.variables {
      printSwiftFunctionThunk(&printer, variable)
      printer.println()
    }

    printDestroyFunctionThunk(&printer, type)
  }

  private func printInitializerThunk(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    guard let translatedDecl = translatedDecl(for: decl) else {
      // Failed to translate. Skip.
      return
    }

    let typeName = translatedDecl.parentName

    printCDecl(
      &printer,
      javaMethodName: "allocatingInit",
      parentName: translatedDecl.parentName,
      parameters: translatedDecl.translatedFunctionSignature.parameters,
      isStatic: true,
      resultType: .long
    ) { printer in
      let downcallArguments = renderDowncallArguments(
        swiftFunctionSignature: decl.functionSignature,
        translatedFunctionSignature: translatedDecl.translatedFunctionSignature
      )
      // TODO: Throwing initializers
      printer.print(
        """
        let selfPointer = UnsafeMutablePointer<\(typeName)>.allocate(capacity: 1)
        selfPointer.initialize(to: \(typeName)(\(downcallArguments)))
        return Int64(Int(bitPattern: selfPointer)).getJNIValue(in: environment)
        """
      )
    }
  }

  private func printSwiftFunctionThunk(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let _ = translatedDecl(for: decl) else {
      // Failed to translate. Skip.
      return
    }

    // Free functions does not have a parent
    if decl.isStatic || !decl.hasParent {
      self.printSwiftStaticFunctionThunk(&printer, decl)
    } else {
      self.printSwiftMemberFunctionThunk(&printer, decl)
    }
  }

  private func printSwiftStaticFunctionThunk(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    let translatedDecl = self.translatedDecl(for: decl)!

    printCDecl(
      &printer,
      javaMethodName: translatedDecl.name,
      parentName: translatedDecl.parentName,
      parameters: translatedDecl.translatedFunctionSignature.parameters,
      isStatic: true,
      resultType: translatedDecl.translatedFunctionSignature.resultType
    ) { printer in
      // For free functions the parent is the Swift module
      let parentName = decl.parentType?.asNominalTypeDeclaration?.qualifiedName ?? swiftModuleName
      self.printFunctionDowncall(&printer, decl, calleeName: parentName)
    }
  }

  private func printSwiftMemberFunctionThunk(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    let translatedDecl = self.translatedDecl(for: decl)!
    let swiftParentName = decl.parentType!.asNominalTypeDeclaration!.qualifiedName

    printCDecl(
      &printer,
      javaMethodName: "$\(translatedDecl.name)",
      parentName: translatedDecl.parentName,
      parameters: translatedDecl.translatedFunctionSignature.parameters + [
        JavaParameter(name: "selfPointer", type: .long)
      ],
      isStatic: true,
      resultType: translatedDecl.translatedFunctionSignature.resultType
    ) { printer in
      printer.print(
        """
        let self$ = UnsafeMutablePointer<\(swiftParentName)>(bitPattern: Int(Int64(fromJNI: selfPointer, in: environment!)))!
        """
      )
      self.printFunctionDowncall(&printer, decl, calleeName: "self$.pointee")
    }
  }

  private func printFunctionDowncall(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    calleeName: String
  ) {
    let translatedDecl = self.translatedDecl(for: decl)!
    let swiftReturnType = decl.functionSignature.result.type

    let tryClause: String = decl.isThrowing ? "try " : ""

    let result: String
    switch decl.apiKind {
    case .function, .initializer:
      let downcallParameters = renderDowncallArguments(
        swiftFunctionSignature: decl.functionSignature,
        translatedFunctionSignature: translatedDecl.translatedFunctionSignature
      )
      result = "\(tryClause)\(calleeName).\(decl.name)(\(downcallParameters))"

    case .getter:
      result = "\(tryClause)\(calleeName).\(decl.name)"

    case .setter:
      guard let newValueParameter = decl.functionSignature.parameters.first else {
        fatalError("Setter did not contain newValue parameter: \(decl)")
      }

      result = "\(calleeName).\(decl.name) = \(renderJNIToSwiftConversion("newValue", type: newValueParameter.type))"
    }

    let returnStatement =
    if swiftReturnType.isVoid {
      result
    } else {
      """
      let result = \(result)
      return result.getJNIValue(in: environment)
      """
    }

    if decl.isThrowing {
      let dummyReturn =
      !swiftReturnType.isVoid ? "return \(swiftReturnType).jniPlaceholderValue" : ""
      printer.print(
          """
          do {
            \(returnStatement)
          } catch {
            environment.throwAsException(error)
            \(dummyReturn)
          }
          """
      )
    } else {
      printer.print(returnStatement)
    }
  }

  private func printCDecl(
    _ printer: inout CodePrinter,
    javaMethodName: String,
    parentName: String,
    parameters: [JavaParameter],
    isStatic: Bool,
    resultType: JavaType,
    _ body: (inout CodePrinter) -> Void
  ) {
    let jniSignature = parameters.reduce(into: "") { signature, parameter in
      signature += parameter.type.jniTypeSignature
    }

    let cName =
      "Java_"
      + self.javaPackage.replacingOccurrences(of: ".", with: "_")
      + "_\(parentName.escapedJNIIdentifier)_"
      + javaMethodName.escapedJNIIdentifier
      + "__"
      + jniSignature.escapedJNIIdentifier

    let translatedParameters = parameters.map {
      "\($0.name): \($0.type.jniTypeName)"
    }
    let thisParameter = isStatic ? "thisClass: jclass" : "thisObject: jobject"

    let thunkParameters =
      [
        "environment: UnsafeMutablePointer<JNIEnv?>!",
        thisParameter
      ] + translatedParameters
    let thunkReturnType = !resultType.isVoid ? " -> \(resultType.jniTypeName)" : ""

    // TODO: Think about function overloads
    printer.printBraceBlock(
      """
      @_cdecl("\(cName)")
      func \(cName)(\(thunkParameters.joined(separator: ", ")))\(thunkReturnType)
      """
    ) { printer in
      body(&printer)
    }
  }

  private func printHeader(_ printer: inout CodePrinter) {
    printer.print(
      """
      // Generated by swift-java

      import JavaKit

      """
    )
  }

  /// Prints the implementation of the destroy function.
  private func printDestroyFunctionThunk(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    printCDecl(
      &printer,
      javaMethodName: "$destroy",
      parentName: type.swiftNominal.name,
      parameters: [
        JavaParameter(name: "selfPointer", type: .long)
      ],
      isStatic: true,
      resultType: .void
    ) { printer in
      // Deinitialize the pointer allocated (which will call the VWT destroy method)
      // then deallocate the memory.
      printer.print(
        """
        let pointer = UnsafeMutablePointer<\(type.qualifiedName)>(bitPattern: Int(Int64(fromJNI: selfPointer, in: environment!)))!
        pointer.deinitialize(count: 1)
        pointer.deallocate()
        """
      )
    }
  }

  /// Renders the arguments for making a downcall
  private func renderDowncallArguments(
    swiftFunctionSignature: SwiftFunctionSignature,
    translatedFunctionSignature: TranslatedFunctionSignature
  ) -> String {
    zip(
      swiftFunctionSignature.parameters,
      translatedFunctionSignature.parameters
    ).map { originalParam, translatedParam in
      let label = originalParam.argumentLabel.map { "\($0): " } ?? ""
      return "\(label)\(originalParam.type)(fromJNI: \(translatedParam.name), in: environment!)"
    }
    .joined(separator: ", ")
  }

  private func renderJNIToSwiftConversion(_ variableName: String, type: SwiftType) -> String {
    "\(type)(fromJNI: \(variableName), in: environment!)"
  }
}

extension String {
  /// Returns a version of the string correctly escaped for a JNI
  var escapedJNIIdentifier: String {
    self.map {
      if $0 == "_" {
        return "_1"
      } else if $0 == "/" {
        return "_"
      } else if $0 == ";" {
        return "_2"
      } else if $0 == "[" {
        return "_3"
      } else if $0.isASCII && ($0.isLetter || $0.isNumber)  {
        return String($0)
      } else if let utf16 = $0.utf16.first {
        // Escape any non-alphanumeric to their UTF16 hex encoding
        let utf16Hex = String(format: "%04x", utf16)
        return "_0\(utf16Hex)"
      } else {
        fatalError("Invalid JNI character: \($0)")
      }
    }
    .joined()
  }
}
