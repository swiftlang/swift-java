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
  }

  private func printNominalTypeThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) throws {
    printHeader(&printer)

    for decl in type.methods {
      printSwiftFunctionThunk(&printer, decl, sorroundingType: type)
      printer.println()
    }
  }

  private func printSwiftFunctionThunk(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    sorroundingType: ImportedNominalType? = nil
  ) {
    let translatedDecl = translatedDecl(for: decl)
    let parentName = sorroundingType?.swiftNominal.qualifiedName ?? swiftModuleName

    let cName =
      "Java_" + self.javaPackage.replacingOccurrences(of: ".", with: "_") + "_\(parentName)_"
      + decl.name
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    // TODO: Add a similair construct as `LoweredFunctionSignature` to `TranslatedFunctionSignature`
    let translatedParameters = translatedDecl.translatedFunctionSignature.parameters.map { param in
      (param.name, param.type)
    }

    let thunkParameters =
      [
        "environment: UnsafeMutablePointer<JNIEnv?>!",
        "thisClass: jclass",
      ] + translatedParameters.map { "\($0.0): \($0.1.jniTypeName)" }
    let swiftReturnType = decl.functionSignature.result.type
    let thunkReturnType =
    !swiftReturnType.isVoid ? " -> \(translatedDecl.translatedFunctionSignature.resultType.jniTypeName)" : ""

    printer.printBraceBlock(
      """
      @_cdecl("\(cName)")
      func \(thunkName)(\(thunkParameters.joined(separator: ", ")))\(thunkReturnType)
      """
    ) { printer in
      let downcallParameters = zip(decl.functionSignature.parameters, translatedParameters).map {
        originalParam, translatedParam in
        let label = originalParam.argumentLabel.map { "\($0): " } ?? ""
        return "\(label)\(originalParam.type)(fromJNI: \(translatedParam.0), in: environment!)"
      }
      let tryClause: String = decl.isThrowing ? "try " : ""
      let functionDowncall =
        "\(tryClause)\(parentName).\(decl.name)(\(downcallParameters.joined(separator: ", ")))"

      let innerBody =
        if swiftReturnType.isVoid {
          functionDowncall
        } else {
          """
          let result = \(functionDowncall)
          return result.getJNIValue(in: environment)
          """
        }

      if decl.isThrowing {
        let dummyReturn =
          !swiftReturnType.isVoid ? "return \(swiftReturnType).jniPlaceholderValue" : ""
        printer.print(
          """
          do {
            \(innerBody)
          } catch {
            environment.throwAsException(error)
            \(dummyReturn)
          }
          """
        )
      } else {
        printer.print(innerBody)
      }
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
}
