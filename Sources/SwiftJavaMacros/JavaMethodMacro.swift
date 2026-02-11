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

import SwiftSyntax
import SwiftSyntaxBuilder
@_spi(Testing) import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

package enum JavaMethodMacro {}

extension JavaMethodMacro: BodyMacro {
  package static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    // @JavaMethod only provides an implementation when the method was
    // imported from Java.
    let mode = GenerationMode(expansionContext: context)

    // FIXME: nil is a workaround for the fact that extension JavaClass doesn't
    // currently have the annotations we need. We should throw
    // MacroErrors.macroOutOfContext(node.attributeName.trimmedDescription)

    switch mode {
    case .javaImplementation, .exportToJava:
      return declaration.body.map { Array($0.statements) } ?? []

    case .importFromJava, nil:
      break
    }

    // Handle initializers separately.
    if let initDecl = declaration.as(InitializerDeclSyntax.self) {
      return try bridgeInitializer(initDecl, in: context)
    }

    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      fatalError("not a function: \(declaration)")
    }

    let funcName =
      if case .argumentList(let arguments) = node.arguments,
        let argument = arguments.first,
        argument.label?.text != "typeErasedResult",
        let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
        stringLiteral.segments.count == 1,
        case let .stringSegment(funcNameSegment)? = stringLiteral.segments.first
      {
        funcNameSegment.content.text
      } else {
        funcDecl.name.text
      }

    let isStatic = node.attributeName.trimmedDescription == "JavaStaticMethod"
    let params = funcDecl.signature.parameterClause.parameters
    let paramNames = params.map { param in param.parameterName?.text ?? "" }.joined(separator: ", ")

    let genericResultType: String? =
      if case let .argumentList(arguments) = node.arguments,
        let element = arguments.first(where: { $0.label?.text == "typeErasedResult" }),
        let stringLiteral = element.expression
          .as(StringLiteralExprSyntax.self),
        stringLiteral.segments.count == 1,
        case let .stringSegment(wrapperName)? = stringLiteral.segments.first
      {
        // TODO: Improve this unwrapping a bit;
        // Trim the trailing ! and ? from the type for purposes
        // of initializing the type wrapper in the method body
        if "\(wrapperName)".hasSuffix("!") || "\(wrapperName)".hasSuffix("?") {
          String("\(wrapperName)".dropLast())
        } else {
          "\(wrapperName)"
        }
      } else {
        nil
      }

    // Determine the result type
    let resultType: String =
      if let returnClause = funcDecl.signature.returnClause {
        if let genericResultType {
          // we need to type-erase the signature, because on JVM level generics are erased and we'd otherwise
          // form a signature with the "concrete" type, which would not match the real byte-code level signature
          // of the method we're trying to call -- which would result in a MethodNotFound exception.
          ", resultType: /*type-erased:\(genericResultType)*/JavaObject?.self"
        } else {
          ", resultType: \(returnClause.type.typeReferenceString).self"
        }
      } else {
        ""
      }

    let parametersAsArgs: String
    if paramNames.isEmpty {
      parametersAsArgs = ""
    } else {
      parametersAsArgs = ", arguments: \(paramNames)"
    }

    let canRethrowError = funcDecl.signature.effectSpecifiers?.throwsClause != nil
    let catchPhrase =  // how are we able to catch/handle thrown errors from the dynamicJava call
      if canRethrowError {
        "throw error"
      } else {
        """
        if let throwable = error as? Throwable {
          let sw = StringWriter()
          let pw = PrintWriter(sw)
          throwable.printStackTrace(pw)
          fatalError("Java call threw unhandled exception: \\(error)\\n\\(sw.toString())")
        }
        fatalError("Java call threw unhandled exception: \\(error)")
        """
      }

    let resultSyntax: CodeBlockItemSyntax =
      """
      \(raw: canRethrowError ? "try " : ""){
        do {
          return try dynamicJava\(raw: isStatic ? "Static" : "")MethodCall(methodName: \(literal: funcName)\(raw: parametersAsArgs)\(raw: resultType))
        } catch {
          \(raw: catchPhrase)
        }
      }()
      """

    if let genericResultType {
      return [
        """
        /* convert erased return value to \(raw: genericResultType) */
        let result$ = \(resultSyntax)
        if let result$ {
          return \(raw: genericResultType)(javaThis: result$.javaThis, environment: try! JavaVirtualMachine.shared().environment())
        } else {
          return nil
        }
        """
      ]
    }

    // no return type conversions
    return [
      "return \(resultSyntax)"
    ]
  }

  /// Bridge an initializer into a call to Java.
  private static func bridgeInitializer(
    _ initDecl: InitializerDeclSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    // Extract the "environment" parameter.
    guard let environmentIndex = initDecl.signature.parameterClause.parameters.indexOfParameter(named: "environment")
    else {
      throw MacroErrors.missingEnvironment
    }

    // Collect the arguments that need to be passed through to the
    // Java constructor.
    let parameters = initDecl.signature.parameterClause.parameters
    var arguments: String = ""
    for paramIndex in parameters.indices {
      // Don't include the "environment" parameter.
      if paramIndex == environmentIndex {
        continue
      }

      let param = parameters[paramIndex]
      arguments += "\(param.parameterName!).self, "
    }

    if !arguments.isEmpty {
      arguments = ", arguments: \(arguments.dropLast(2))"
    }

    let tryKeyword =
      initDecl.signature.effectSpecifiers?.throwsClause != nil
      ? "try" : "try!"

    let objectCreation: [CodeBlockItemSyntax]
    if context.lexicalContext.first?.is(ClassDeclSyntax.self) ?? false {
      objectCreation = [
        "let javaThis = \(raw: tryKeyword) Self.dynamicJavaNewObjectInstance(in: _environment\(raw: arguments))\n",
        "self.init(javaThis: javaThis, environment: _environment)\n",
      ]
    } else {
      objectCreation = [
        "self = \(raw: tryKeyword) Self.dynamicJavaNewObject(in: _environment\(raw: arguments))\n"
      ]
    }
    return [
      """
      let _environment = if let environment {
          environment
      } else {
          \(raw: tryKeyword) JavaVirtualMachine.shared().environment()
      }
      """
    ] + objectCreation
  }
}

extension FunctionParameterListSyntax {
  func indexOfParameter(named name: String) -> Index? {
    firstIndex { $0.parameterName?.text == name }
  }
}

extension TypeSyntaxProtocol {
  /// Produce a reference to the given type syntax node with any adjustments
  /// needed to pretty-print it back into source.
  var typeReference: TypeSyntax {
    if let iuoType = self.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      return TypeSyntax(
        OptionalTypeSyntax(
          wrappedType: iuoType.wrappedType.trimmed
        )
      )
    }

    return TypeSyntax(trimmed)
  }

  /// Produce a reference to the given type syntax node with any adjustments
  /// needed to pretty-print it back into source, as a string.
  var typeReferenceString: String {
    typeReference.description
  }
}
