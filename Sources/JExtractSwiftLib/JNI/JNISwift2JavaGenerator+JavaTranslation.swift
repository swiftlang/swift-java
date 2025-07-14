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

import JavaTypes

extension JNISwift2JavaGenerator {
  func translatedDecl(
    for decl: ImportedFunc
  ) -> TranslatedFunctionDecl {
    if let cached = translatedDecls[decl] {
      return cached
    }

    let translation = JavaTranslation(swiftModuleName: self.swiftModuleName)
    let translated = translation.translate(decl)

    translatedDecls[decl] = translated
    return translated
  }

  struct JavaTranslation {
    let swiftModuleName: String

    func translate(_ decl: ImportedFunc) -> TranslatedFunctionDecl {
      let translatedFunctionSignature = translate(functionSignature: decl.functionSignature)
      // Types with no parent will be outputted inside a "module" class.
      let parentName = decl.parentType?.asNominalType?.nominalTypeDecl.qualifiedName ?? swiftModuleName

      return TranslatedFunctionDecl(
        name: decl.name,
        parentName: parentName,
        translatedFunctionSignature: translatedFunctionSignature
      )
    }

    func translate(functionSignature: SwiftFunctionSignature, isInitializer: Bool = false) -> TranslatedFunctionSignature {
      let parameters = functionSignature.parameters.enumerated().map { idx, param in
        let parameterName = param.parameterName ?? "arg\(idx))"
        return translate(swiftParam: param, parameterName: parameterName)
      }

      return TranslatedFunctionSignature(
        parameters: parameters,
        resultType: translate(swiftType: functionSignature.result.type)
      )
    }

    func translate(swiftParam: SwiftParameter, parameterName: String) -> JavaParameter {
      return JavaParameter(
        name: parameterName,
        type: translate(swiftType: swiftParam.type)
      )
    }

    func translate(swiftType: SwiftType) -> JavaType {
      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = translate(knownType: knownType) else {
            fatalError("unsupported known type: \(knownType)")
          }
          return javaType
        }

        return .class(package: nil, name: nominalType.nominalTypeDecl.name)

      case .tuple([]):
        return .void

      case .metatype, .optional, .tuple, .function, .existential, .opaque:
        fatalError("unsupported type: \(self)")
      }
    }

    func translate(knownType: SwiftKnownTypeDeclKind) -> JavaType? {
      switch knownType {
      case .bool: .boolean
      case .int8: .byte
      case .uint16: .char
      case .int16: .short
      case .int32: .int
      case .int64: .long
      case .float: .float
      case .double: .double
      case .void: .void
      case .string: .javaLangString
      case .int, .uint, .uint8, .uint32, .uint64,
          .unsafeRawPointer, .unsafeMutableRawPointer,
          .unsafePointer, .unsafeMutablePointer,
          .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer,
          .unsafeBufferPointer, .unsafeMutableBufferPointer, .optional, .data, .dataProtocol:
        nil
      }
    }
  }

  struct TranslatedFunctionDecl {
    /// Java function name
    let name: String

    /// The name of the Java parent scope this function is declared in
    let parentName: String

    /// Function signature
    let translatedFunctionSignature: TranslatedFunctionSignature
  }

  struct TranslatedFunctionSignature {
    let parameters: [JavaParameter]
    let resultType: JavaType
  }
}
