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

    for initializer in type.initializers {
      printInitializerThunk(&printer, initializer)
      printer.println()
    }

    for method in type.methods {
      printSwiftFunctionThunk(&printer, method)
      printer.println()
    }
  }

  private func printInitializerThunk(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    let translatedDecl = translatedDecl(for: decl)
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
    let translatedDecl = self.translatedDecl(for: decl)
    let parentName = translatedDecl.parentName
    let swiftReturnType = decl.functionSignature.result.type

    printCDecl(&printer, decl) { printer in
      let downcallParameters = renderDowncallArguments(
        swiftFunctionSignature: decl.functionSignature,
        translatedFunctionSignature: translatedDecl.translatedFunctionSignature
      )
      let tryClause: String = decl.isThrowing ? "try " : ""
      let functionDowncall =
        "\(tryClause)\(parentName).\(decl.name)(\(downcallParameters))"

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

  private func printCDecl(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    _ body: (inout CodePrinter) -> Void
  ) {
    let translatedDecl = translatedDecl(for: decl)
    let parentName = translatedDecl.parentName

    printCDecl(
      &printer,
      javaMethodName: translatedDecl.name,
      parentName: parentName,
      parameters: translatedDecl.translatedFunctionSignature.parameters,
      isStatic: decl.isStatic || decl.isInitializer || !decl.hasParent,
      resultType: translatedDecl.translatedFunctionSignature.resultType,
      body
    )
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
    var jniSignature = parameters.reduce(into: "") { signature, parameter in
      signature += parameter.type.jniTypeSignature
    }

    // Escape signature characters
    jniSignature = jniSignature
      .replacingOccurrences(of: "_", with: "_1")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ";", with: "_2")
      .replacingOccurrences(of: "[", with: "_3")

    let cName =
      "Java_"
      + self.javaPackage.replacingOccurrences(of: ".", with: "_")
      + "_\(parentName)_"
      + javaMethodName
      + "__"
      + jniSignature
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
}
