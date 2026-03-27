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

package enum JavaImplementationMacro {}

// JNI identifier escaping per the JNI specification:
// https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/design.html#resolving_native_method_names
extension String {
  /// Returns the string with characters escaped according to JNI symbol naming rules.
  /// - `_` → `_1`
  /// - `.` and `/` → `_` (package/class separator)
  /// - `;` → `_2`
  /// - `[` → `_3`
  /// - Non-ASCII → `_0XXXX` (UTF-16 hex)
  var escapedJNIIdentifier: String {
    self.compactMap { ch -> String in
      switch ch {
      case "_": return "_1"
      case "/": return "_"
      case ";": return "_2"
      case "[": return "_3"
      default:
        if ch.isASCII && (ch.isLetter || ch.isNumber) {
          return String(ch)
        } else if let utf16 = ch.utf16.first {
          return "_0\(String(format: "%04x", utf16))"
        } else {
          fatalError("Invalid JNI character: \(ch)")
        }
      }
    }.joined()
  }
}

extension JavaImplementationMacro: PeerMacro {
  package static func expansion(
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

      // If @JavaMethod has a name argument (e.g., @JavaMethod("$size")), use it as the JNI method name.
      // Otherwise, fall back to the Swift function name.
      let jniMethodName: String = {
        guard
          let javaMethodAttr = attributes.compactMap({ attr -> AttributeSyntax? in
            guard case .attribute(let attribute) = attr,
              attribute.attributeName.trimmedDescription == "JavaMethod"
            else {
              return nil
            }
            return attribute
          }).first,
          case .argumentList(let args) = javaMethodAttr.arguments,
          let firstArg = args.first,
          firstArg.label == nil || firstArg.label?.text == "javaMethodName",
          let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
          stringLiteral.segments.count == 1,
          case let .stringSegment(nameSegment)? = stringLiteral.segments.first
        else {
          return swiftName
        }
        return nameSegment.content.text
      }()

      let escapedClassName = className.split(separator: ".").map { String($0).escapedJNIIdentifier }.joined(separator: "_")
      let cName = "Java_" + escapedClassName + "_" + jniMethodName.escapedJNIIdentifier
      let innerBody: CodeBlockItemListSyntax
      let isThrowing = memberFunc.signature.effectSpecifiers?.throwsClause != nil
      let tryClause: String = isThrowing ? "try " : ""
      let getJNIValue: String =
        returnType != nil
        ? "\n  .getJNILocalRefValue(in: environment)"
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
        public func \(context.makeUniqueName(swiftName))(\(raw: cParameters.map{ $0.description }.joined(separator: ", ")))\(raw: cReturnType) {
        \(body)
        }
        """
      )
    }

    return exposedMembers
  }
}
