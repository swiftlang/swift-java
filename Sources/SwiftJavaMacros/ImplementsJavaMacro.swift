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
import SwiftSyntaxMacros

enum JavaImplementationMacro {}

extension JavaImplementationMacro: PeerMacro {
  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
      throw MacroErrors.javaImplementationRequiresExtension
    }

    // Dig out the Java class name.
    guard case .argumentList(let arguments) = node.arguments,
      let wrapperTypeNameExpr = arguments.first?.expression,
      let stringLiteral = wrapperTypeNameExpr.as(StringLiteralExprSyntax.self),
      stringLiteral.segments.count == 1,
      case let .stringSegment(classNameSegment)? = stringLiteral.segments.first
    else {
      throw MacroErrors.classNameNotStringLiteral
    }

    // Check that the class name is fully-qualified, as it should be.
    let className = classNameSegment.content.text
    if className.firstIndex(of: ".") == nil {
      throw MacroErrors.classNameNotFullyQualified(className)
    }

    var exposedMembers: [DeclSyntax] = []
    for memberItem in extensionDecl.memberBlock.members {
      let memberDecl = memberItem.decl

      guard let attributes = memberDecl.asProtocol(WithAttributesSyntax.self)?.attributes,
        attributes.contains(where: {
          guard case .attribute(let attribute) = $0 else {
            return false
          }
          return attribute.attributeName.trimmedDescription == "JavaMethod"
        }),
        let memberFunc = memberDecl.as(FunctionDeclSyntax.self)
      else {
        continue
      }

      let isStatic = memberFunc.modifiers.contains { modifier in
        modifier.name.text == "static"
      }

      // Static functions exposed to Java must have an "environment" parameter.
      // We remove it from the signature of the native C function we expose.
      var parametersClause = memberFunc.signature.parameterClause
      let environmentIndex = parametersClause.parameters.indexOfParameter(named: "environment")
      if isStatic {
        guard let environmentIndex else {
          throw MacroErrors.missingEnvironment
        }

        parametersClause.parameters.remove(at: environmentIndex)
      }

      // Map the parameters.
      let cParameters: [FunctionParameterSyntax] =
        [
          "environment: UnsafeMutablePointer<JNIEnv?>!",
          isStatic ? "thisClass: jclass" : "thisObj: jobject",
        ]
        + parametersClause.parameters.map { param in
          param.with(\.type, "\(param.type).JNIType")
            .with(\.trailingComma, nil)
        }

      // Map the arguments.
      let swiftArguments: [ExprSyntax] = memberFunc.signature.parameterClause.parameters.map { param in
        let label =
          if let argumentName = param.argumentName {
            "\(argumentName):"
          } else {
            ""
          }

        // The "environment" is passed through directly.
        if let environmentIndex, memberFunc.signature.parameterClause.parameters[environmentIndex] == param {
          return "\(raw: label)\(param.secondName ?? param.firstName)"
        }

        return "\(raw: label)\(param.type)(fromJNI: \(param.secondName ?? param.firstName), in: environment!)"
      }

      // Map the return type, if there is one.
      let returnType = memberFunc.signature.returnClause?.type.trimmed
      let cReturnType =
        returnType.map {
          "-> \($0).JNIType"
        } ?? ""

      let swiftName = memberFunc.name.text
      let cName = "Java_" + className.replacingOccurrences(of: ".", with: "_") + "_" + swiftName
      let innerBody: CodeBlockItemListSyntax
      let isThrowing = memberFunc.signature.effectSpecifiers?.throwsClause != nil
      let tryClause: String = isThrowing ? "try " : ""
      let getJNIValue: String =
        returnType != nil
        ? "\n  .getJNIValue(in: environment)"
        : ""
      let swiftTypeName = extensionDecl.extendedType.trimmedDescription
      if isStatic {
        innerBody = """
            return \(raw: tryClause)\(raw: swiftTypeName).\(raw: swiftName)(\(raw: swiftArguments.map { $0.description }.joined(separator: ", ")))\(raw: getJNIValue)
          """
      } else {
        innerBody = """
            let obj = \(raw: swiftTypeName)(javaThis: thisObj, environment: environment!)
            return \(raw: tryClause)obj.\(raw: swiftName)(\(raw: swiftArguments.map { $0.description }.joined(separator: ", ")))\(raw: getJNIValue)
          """
      }

      let body: CodeBlockItemListSyntax
      if isThrowing {
        let dummyReturn: StmtSyntax
        if let returnType {
          dummyReturn = "return \(returnType).jniPlaceholderValue"
        } else {
          dummyReturn = "return ()"
        }
        body = """
            do {
              \(innerBody)
            } catch let error {
              environment.throwAsException(error)
              \(dummyReturn)
            }
          """
      } else {
        body = innerBody
      }

      exposedMembers.append(
        """
        @_cdecl(\(literal: cName))
        func \(context.makeUniqueName(swiftName))(\(raw: cParameters.map{ $0.description }.joined(separator: ", ")))\(raw: cReturnType) {
        \(body)
        }
        """
      )
    }

    return exposedMembers
  }
}
