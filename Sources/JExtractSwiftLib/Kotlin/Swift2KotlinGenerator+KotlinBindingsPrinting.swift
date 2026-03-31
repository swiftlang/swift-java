//
//  Swift2KotlinGenerator+KotlinBindingsPrinting.swift
//  swift-java
//
//  Created by Tanish Azad on 30/03/26.
//

import CodePrinting

extension Swift2KotlinGenerator {
  /// Print the calling body that forwards all the parameters to the `methodName`,
  package func printKotlinBindingPlaceholder(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
  ) {
    let translated = self.translatedDecl(for: decl)!
    let methodName = translated.name

    var modifiers = "public"
    switch decl.functionSignature.selfParameter {
    case .staticMethod, .initializer, nil:
      modifiers.append(" static")
    default:
      break
    }

    let translatedSignature = translated.translatedSignature
    let returnTy = translatedSignature.result.javaResultType

    var annotationsStr = translatedSignature.annotations.map({ $0.render() }).joined(separator: "\n")
    if !annotationsStr.isEmpty { annotationsStr += "\n" }

    var paramDecls = translatedSignature.parameters
      .flatMap(\.kotlinParameters)
      .map { $0.renderParameter() }
    
    TranslatedKotlinDocumentation.printDocumentation(
      importedFunc: decl,
      translatedDecl: translated,
      in: &printer,
    )
    printer.printBraceBlock(
      """
      \(annotationsStr)fun \(methodName)(\(paramDecls.joined(separator: ", "))): \(returnTy)
      """
    ) { printer in
      printer.print("TODO(\"Not implemented\")")
    }
  }
}
