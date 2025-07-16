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
  ) -> TranslatedFunctionDecl? {
    if let cached = translatedDecls[decl] {
      return cached
    }

    let translated: TranslatedFunctionDecl?
    do {
      let translation = JavaTranslation(swiftModuleName: swiftModuleName)
      translated = try translation.translate(decl)
    } catch {
      self.logger.debug("Failed to translate: '\(decl.swiftDecl.qualifiedNameForDebug)'; \(error)")
      translated = nil
    }

    translatedDecls[decl] = translated
    return translated
  }

  struct JavaTranslation {
    let swiftModuleName: String

    func translate(_ decl: ImportedFunc) throws -> TranslatedFunctionDecl {
      let translatedFunctionSignature = try translate(functionSignature: decl.functionSignature)
      // Types with no parent will be outputted inside a "module" class.
      let parentName = decl.parentType?.asNominalType?.nominalTypeDecl.qualifiedName ?? swiftModuleName

      // Name.
      let javaName = switch decl.apiKind {
      case .getter: decl.javaGetterName
      case .setter: decl.javaSetterName
      case .function, .initializer: decl.name
      }

      return TranslatedFunctionDecl(
        name: javaName,
        parentName: parentName,
        translatedFunctionSignature: translatedFunctionSignature
      )
    }

    func translate(functionSignature: SwiftFunctionSignature, isInitializer: Bool = false) throws -> TranslatedFunctionSignature {
      let parameters = try functionSignature.parameters.enumerated().map { idx, param in
        let parameterName = param.parameterName ?? "arg\(idx))"
        return try translate(swiftParam: param, parameterName: parameterName)
      }

      return try TranslatedFunctionSignature(
        parameters: parameters,
        resultType: translate(swiftType: functionSignature.result.type)
      )
    }

    func translate(swiftParam: SwiftParameter, parameterName: String) throws -> JavaParameter {
      return try JavaParameter(
        name: parameterName,
        type: translate(swiftType: swiftParam.type)
      )
    }

    func translate(swiftType: SwiftType) throws -> JavaType {
      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = translate(knownType: knownType) else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }
          return javaType
        }

        return .class(package: nil, name: nominalType.nominalTypeDecl.name)

      case .tuple([]):
        return .void

      case .metatype, .optional, .tuple, .function, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
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

  enum JavaTranslationError: Error {
    case unsupportedSwiftType(SwiftType)
  }
}
