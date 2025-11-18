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
import SwiftJavaConfigurationShared
import SwiftSyntax

extension JNISwift2JavaGenerator {

  func translateProtocolWrappers(
    _ types: [ImportedNominalType]
  ) -> [ImportedNominalType: JavaInterfaceProtocolWrapper] {
    var wrappers = [ImportedNominalType: JavaInterfaceProtocolWrapper]()

    for type in types {
      do {
        let translator = JavaInterfaceProtocolTranslator()
        wrappers[type] = try translator.translate(type)
      } catch {
        self.logger.debug("Failed to generate protocol wrapper for: '\(type.swiftNominal.qualifiedName)'; \(error)")
      }
    }

    return wrappers
  }

  struct JavaInterfaceProtocolWrapper {
    let protocolType: SwiftNominalType
    let functions: [Function]
    let variables: [Variable]

    var wrapperName: String {
      protocolType.nominalTypeDecl.javaInterfaceSwiftProtocolWrapperName
    }

    var swiftName: String {
      protocolType.nominalTypeDecl.qualifiedName
    }

    var javaInterfaceVariableName: String {
      protocolType.nominalTypeDecl.javaInterfaceVariableName
    }

    var javaInterfaceName: String {
      protocolType.nominalTypeDecl.javaInterfaceName
    }

    struct Function {
      let swiftFunctionName: String
      let originalFunctionSignature: SwiftFunctionSignature
      let swiftDecl: any DeclSyntaxProtocol
      let parameterConversions: [UpcallConversionStep]
      let resultConversion: UpcallConversionStep
    }

    struct Variable {
      let swiftDecl: any DeclSyntaxProtocol
      let getter: Function
      let setter: Function?
    }
  }


  struct JavaInterfaceProtocolTranslator {
    func translate(_ type: ImportedNominalType) throws -> JavaInterfaceProtocolWrapper {
      let functions = try type.methods.map { method in
        try translate(function: method)
      }

      let variables = try Dictionary(grouping: type.variables, by: { $0.swiftDecl.id }).map { (id, funcs) in
        assert(funcs.count > 0 && funcs.count <= 2, "Variables must contain a getter and optionally a setter")
        guard let getter = funcs.first(where: { $0.apiKind == .getter }) else {
          fatalError("")
        }
        let setter = funcs.first(where: { $0.apiKind == .setter })

        return try self.translateVariable(getter: getter, setter: setter)
      }

      return JavaInterfaceProtocolWrapper(
        protocolType: SwiftNominalType(nominalTypeDecl: type.swiftNominal),
        functions: functions,
        variables: variables
      )
    }

    func translate(function: ImportedFunc) throws -> JavaInterfaceProtocolWrapper.Function {
      let parameters = try function.functionSignature.parameters.map {
        try self.translateParameter($0)
      }

      let result = try translateResult(function.functionSignature.result, methodName: function.name)

      return JavaInterfaceProtocolWrapper.Function(
        swiftFunctionName: function.name,
        originalFunctionSignature: function.functionSignature,
        swiftDecl: function.swiftDecl,
        parameterConversions: parameters,
        resultConversion: result
      )
    }

    func translateVariable(getter: ImportedFunc, setter: ImportedFunc?) throws -> JavaInterfaceProtocolWrapper.Variable {
      return try JavaInterfaceProtocolWrapper.Variable(
        swiftDecl: getter.swiftDecl, // they should be the same
        getter: translate(function: getter),
        setter: setter.map { try self.translate(function: $0) }
      )
    }

    private func translateParameter(_ parameter: SwiftParameter) throws -> UpcallConversionStep {
      let parameterName = parameter.parameterName!

      switch parameter.type {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard knownType.isDirectlyTranslatedToWrapJava else {
            throw JavaTranslationError.unsupportedSwiftType(parameter.type)
          }

          return .placeholder
        }

        // We assume this is then a JExtracted Swift class
        return .toJavaWrapper(
          .placeholder,
          name: parameterName,
          nominalType: nominalType
        )

      case .tuple([]): // void
        return .placeholder

      case .genericParameter, .function, .metatype, .optional, .tuple, .existential, .opaque, .composite, .array:
        throw JavaTranslationError.unsupportedSwiftType(parameter.type)
      }
    }

    private func translateResult(_ result: SwiftResult, methodName: String) throws -> UpcallConversionStep {
      switch result.type {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard knownType.isDirectlyTranslatedToWrapJava else {
            throw JavaTranslationError.unsupportedSwiftType(result.type)
          }

          return .placeholder
        }

        // We assume this is then a JExtracted Swift class
        return .toSwiftClass(
          .unwrapOptional(.placeholder, message: "Upcall to \(methodName) unexpectedly returned nil"),
          name: "result$",
          nominalType: nominalType
        )

      case .tuple([]): // void
        return .placeholder

      case .genericParameter, .function, .metatype, .optional, .tuple, .existential, .opaque, .composite, .array:
        throw JavaTranslationError.unsupportedSwiftType(result.type)
      }
    }
  }
}

  /// Describes how to convert values from and to wrap-java types
  enum UpcallConversionStep {
    /// The value being converted
    case placeholder

    case constant(String)

    indirect case toJavaWrapper(
      UpcallConversionStep,
      name: String,
      nominalType: SwiftNominalType
    )

    indirect case toSwiftClass(
      UpcallConversionStep,
      name: String,
      nominalType: SwiftNominalType
    )

    indirect case unwrapOptional(
      UpcallConversionStep,
      message: String
    )

    /// Returns the conversion string applied to the placeholder.
    func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
      switch self {
      case .placeholder:
        return placeholder

      case .constant(let constant):
        return constant

      case .toJavaWrapper(let inner, let name, let nominalType):
        let inner = inner.render(&printer, placeholder)
        printer.print(
          """
          let \(name)Class = try! JavaClass<\(nominalType.nominalTypeDecl.generatedJavaClassMacroName)>(environment: JavaVirtualMachine.shared().environment())
          let \(name)Pointer = UnsafeMutablePointer<\(nominalType.nominalTypeDecl.qualifiedName)>.allocate(capacity: 1)
          \(name)Pointer.initialize(to: \(inner))
          """
        )

        return "\(name)Class.wrapMemoryAddressUnsafe(Int64(Int(bitPattern: \(name)Pointer)))"

      case .toSwiftClass(let inner, let name, let nominalType):
        let inner = inner.render(&printer, placeholder)

        // The wrap-java methods will return null
        printer.print(
          """
          let \(name)MemoryAddress$ = \(inner).as(JavaJNISwiftInstance.self)!.memoryAddress()
          let \(name)Pointer = UnsafeMutablePointer<\(nominalType.nominalTypeDecl.qualifiedName)>(bitPattern: Int(\(name)MemoryAddress$))!
          """
        )

        return "\(name)Pointer.pointee"

      case .unwrapOptional(let inner, let message):
        let inner = inner.render(&printer, placeholder)

        printer.print(
          """
          guard let unwrapped$ = \(inner) else {
            fatalError("\(message)")
          }
          """
        )

        return "unwrapped$"
      }
    }
}
