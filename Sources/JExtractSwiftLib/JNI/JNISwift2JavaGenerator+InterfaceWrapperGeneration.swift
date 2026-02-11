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

  func generateInterfaceWrappers(
    _ types: [ImportedNominalType]
  ) -> [ImportedNominalType: JavaInterfaceSwiftWrapper] {
    var wrappers = [ImportedNominalType: JavaInterfaceSwiftWrapper]()

    for type in types where type.swiftNominal.kind == .protocol {
      do {
        let translator = JavaInterfaceProtocolWrapperGenerator()
        wrappers[type] = try translator.generate(for: type)
      } catch {
        self.logger.warning("Failed to generate protocol wrapper for: '\(type.swiftNominal.qualifiedName)'; \(error)")
      }
    }

    return wrappers
  }

  /// A type that describes a Swift protocol
  /// that uses an underlying wrap-java `@JavaInterface`
  /// to make callbacks to Java from Swift using protocols.
  struct JavaInterfaceSwiftWrapper {
    let protocolType: SwiftNominalType
    let functions: [Function]
    let variables: [Variable]
    let importedType: ImportedNominalType

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

  /// Represents a synthetic protocol-like translation for escaping closures.
  /// This allows closures to use the same conversion infrastructure as protocols,
  /// providing support for optionals, arrays, custom types, async, etc.
  struct SyntheticClosureFunction {
    /// The wrap-java interface name (e.g., "JavaMyClass.setCallback.callback")
    let wrapJavaInterfaceName: String

    /// Conversion steps for each parameter
    let parameterConversions: [UpcallConversionStep]

    /// Conversion step for the result
    let resultConversion: UpcallConversionStep

    /// The original Swift function type
    let functionType: SwiftFunctionType
  }

  struct JavaInterfaceProtocolWrapperGenerator {
    func generate(for type: ImportedNominalType) throws -> JavaInterfaceSwiftWrapper {
      if !type.initializers.isEmpty
        || type.methods.contains(where: \.isStatic)
        || type.variables.contains(where: \.isStatic)
      {
        throw JavaTranslationError.protocolStaticRequirementsNotSupported
      }

      let functions = try type.methods.map { method in
        try translate(function: method)
      }

      // FIXME: Finish support for variables
      if !type.variables.isEmpty {
        throw JavaTranslationError.protocolVariablesNotSupported
      }

      let variables = try Dictionary(grouping: type.variables, by: { $0.swiftDecl.id }).map { (id, funcs) in
        precondition(funcs.count > 0 && funcs.count <= 2, "Variables must contain a getter and optionally a setter")
        guard let getter = funcs.first(where: { $0.apiKind == .getter }) else {
          fatalError("Getter not found for variable with imported funcs: \(funcs)")
        }
        let setter = funcs.first(where: { $0.apiKind == .setter })

        return try self.translateVariable(getter: getter, setter: setter)
      }

      return JavaInterfaceSwiftWrapper(
        protocolType: SwiftNominalType(nominalTypeDecl: type.swiftNominal),
        functions: functions,
        variables: variables,
        importedType: type
      )
    }

    /// Generates a synthetic closure function translation.
    /// This treats the closure as if it were a protocol with a single `apply` method,
    /// allowing it to use the same conversion infrastructure for optionals, arrays, etc.
    func generateSyntheticClosureFunction(
      functionType: SwiftFunctionType,
      wrapJavaInterfaceName: String
    ) throws -> SyntheticClosureFunction {
      let parameterConversions = try functionType.parameters.enumerated().map { idx, param in
        try self.translateParameter(
          parameterName: param.parameterName ?? "_\(idx)",
          type: param.type
        )
      }

      let resultConversion = try self.translateResult(
        type: functionType.resultType,
        methodName: "apply"
      )

      return SyntheticClosureFunction(
        wrapJavaInterfaceName: wrapJavaInterfaceName,
        parameterConversions: parameterConversions,
        resultConversion: resultConversion,
        functionType: functionType
      )
    }

    private func translate(function: ImportedFunc) throws -> JavaInterfaceSwiftWrapper.Function {
      let parameters = try function.functionSignature.parameters.map {
        try self.translateParameter($0)
      }

      let result = try translateResult(function.functionSignature.result, methodName: function.name)

      return JavaInterfaceSwiftWrapper.Function(
        swiftFunctionName: function.name,
        originalFunctionSignature: function.functionSignature,
        swiftDecl: function.swiftDecl,
        parameterConversions: parameters,
        resultConversion: result
      )
    }

    private func translateVariable(
      getter: ImportedFunc,
      setter: ImportedFunc?
    ) throws -> JavaInterfaceSwiftWrapper.Variable {
      try JavaInterfaceSwiftWrapper.Variable(
        swiftDecl: getter.swiftDecl, // they should be the same
        getter: translate(function: getter),
        setter: setter.map { try self.translate(function: $0) }
      )
    }

    private func translateParameter(_ parameter: SwiftParameter) throws -> UpcallConversionStep {
      try self.translateParameter(parameterName: parameter.parameterName!, type: parameter.type)
    }

    private func translateParameter(parameterName: String, type: SwiftType) throws -> UpcallConversionStep {

      if type.isDirectlyTranslatedToWrapJava {
        return .placeholder
      }

      switch type {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(type)
            }
            return try translateOptionalParameter(
              name: parameterName,
              wrappedType: genericArgs[0]
            )

          case .array:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(type)
            }
            return try translateArrayParameter(
              name: parameterName,
              elementType: genericArgs[0]
            )

          default:
            throw JavaTranslationError.unsupportedSwiftType(type)
          }
        }

        // We assume this is then a JExtracted Swift class
        return .toJavaWrapper(
          .placeholder,
          name: parameterName,
          nominalType: nominalType
        )

      case .tuple([]): // void
        return .placeholder

      case .optional(let wrappedType):
        return try translateOptionalParameter(
          name: parameterName,
          wrappedType: wrappedType
        )

      case .array(let elementType):
        return try translateArrayParameter(name: parameterName, elementType: elementType)

      case .genericParameter, .function, .metatype, .tuple, .existential, .opaque, .composite:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    private func translateArrayParameter(name: String, elementType: SwiftType) throws -> UpcallConversionStep {
      switch elementType {
      case .nominal(let nominalType):
        // We assume this is a JExtracted type
        return .map(
          .placeholder,
          body: .toJavaWrapper(
            .placeholder,
            name: "arrayElement",
            nominalType: nominalType
          )
        )

      case .array, .composite, .existential, .function, .genericParameter, .metatype, .opaque, .optional, .tuple:
        throw JavaTranslationError.unsupportedSwiftType(.array(elementType))
      }
    }

    private func translateOptionalParameter(name: String, wrappedType: SwiftType) throws -> UpcallConversionStep {
      let wrappedConversion = try translateParameter(parameterName: name, type: wrappedType)
      return .toJavaOptional(.map(.placeholder, body: wrappedConversion))
    }

    private func translateResult(_ result: SwiftResult, methodName: String) throws -> UpcallConversionStep {
      try self.translateResult(type: result.type, methodName: methodName)
    }

    private func translateResult(
      type: SwiftType,
      methodName: String,
      allowNilForObjects: Bool = false
    ) throws -> UpcallConversionStep {
      if type.isDirectlyTranslatedToWrapJava {
        return .placeholder
      }

      switch type {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(type)
            }
            return try self.translateOptionalResult(
              wrappedType: genericArgs[0],
              methodName: methodName
            )

          case .array:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(type)
            }
            return try self.translateArrayResult(elementType: genericArgs[0])

          default:
            throw JavaTranslationError.unsupportedSwiftType(type)
          }
        }

        let inner: UpcallConversionStep =
          !allowNilForObjects
          ? .unwrapOptional(.placeholder, message: "Upcall to \(methodName) unexpectedly returned nil")
          : .placeholder

        // We assume this is then a JExtracted Swift class
        return .toSwiftClass(
          inner,
          name: "result$",
          nominalType: nominalType
        )

      case .tuple([]): // void
        return .placeholder

      case .optional(let wrappedType):
        return try self.translateOptionalResult(wrappedType: wrappedType, methodName: methodName)

      case .array(let elementType):
        return try self.translateArrayResult(elementType: elementType)

      case .genericParameter, .function, .metatype, .tuple, .existential, .opaque, .composite:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    private func translateArrayResult(elementType: SwiftType) throws -> UpcallConversionStep {
      switch elementType {
      case .nominal(let nominalType):
        // We assume this is a JExtracted type
        return .map(
          .placeholder,
          body: .toSwiftClass(
            .unwrapOptional(.placeholder, message: "Element of array was nil"),
            name: "arrayElement",
            nominalType: nominalType
          )
        )

      case .array, .composite, .existential, .function, .genericParameter, .metatype, .opaque, .optional, .tuple:
        throw JavaTranslationError.unsupportedSwiftType(.array(elementType))
      }
    }

    private func translateOptionalResult(wrappedType: SwiftType, methodName: String) throws -> UpcallConversionStep {
      // The `fromJavaOptional` will handle the nullability
      let wrappedConversion = try translateResult(
        type: wrappedType,
        methodName: methodName,
        allowNilForObjects: true
      )
      return .map(.fromJavaOptional(.placeholder), body: wrappedConversion)
    }
  }
}

/// Describes how to convert values from and to wrap-java types
enum UpcallConversionStep {
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

  indirect case toJavaOptional(UpcallConversionStep)

  indirect case fromJavaOptional(UpcallConversionStep)

  indirect case map(UpcallConversionStep, body: UpcallConversionStep)

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

    case .toJavaOptional(let inner):
      let inner = inner.render(&printer, placeholder)
      return "\(inner).toJavaOptional()"

    case .fromJavaOptional(let inner):
      let inner = inner.render(&printer, placeholder)
      return "Optional(javaOptional: \(inner))"

    case .map(let inner, let body):
      let inner = inner.render(&printer, placeholder)
      var printer = CodePrinter()
      printer.printBraceBlock("\(inner).map") { printer in
        let body = body.render(&printer, "$0")
        printer.print("return \(body)")
      }
      return printer.finalize()
    }
  }
}

extension SwiftType {
  /// Indicates whether this type is translated by `wrap-java`
  /// into the same type as `jextract`.
  ///
  /// This means we do not have to perform any mapping when passing
  /// this type between jextract and wrap-java
  var isDirectlyTranslatedToWrapJava: Bool {
    switch self {
    case .nominal(let swiftNominalType):
      guard let knownType = swiftNominalType.nominalTypeDecl.knownTypeKind else {
        return false
      }
      switch knownType {
      case .bool, .int, .uint, .int8, .uint8, .int16, .uint16, .int32, .uint32, .int64, .uint64, .float, .double,
        .string, .void:
        return true
      default:
        return false
      }

    case .array(let elementType):
      return elementType.isDirectlyTranslatedToWrapJava

    case .genericParameter, .function, .metatype, .optional, .tuple, .existential, .opaque, .composite:
      return false
    }
  }
}
