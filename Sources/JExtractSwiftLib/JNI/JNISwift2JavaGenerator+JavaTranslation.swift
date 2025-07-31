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
      let translation = JavaTranslation(
        swiftModuleName: swiftModuleName,
        javaPackage: self.javaPackage,
        javaClassLookupTable: self.javaClassLookupTable
      )
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
    let javaPackage: String
    let javaClassLookupTable: JavaClassLookupTable

    func translate(_ decl: ImportedFunc) throws -> TranslatedFunctionDecl {
      let nativeTranslation = NativeJavaTranslation(
        javaPackage: self.javaPackage,
        javaClassLookupTable: self.javaClassLookupTable
      )

      // Types with no parent will be outputted inside a "module" class.
      let parentName = decl.parentType?.asNominalType?.nominalTypeDecl.qualifiedName ?? swiftModuleName

      // Name.
      let javaName = switch decl.apiKind {
      case .getter: decl.javaGetterName
      case .setter: decl.javaSetterName
      case .function, .initializer: decl.name
      }

      // Swift -> Java
      let translatedFunctionSignature = try translate(
        functionSignature: decl.functionSignature,
        methodName: javaName,
        parentName: parentName
      )
      // Java -> Java (native)
      let nativeFunctionSignature = try nativeTranslation.translate(
        functionSignature: decl.functionSignature,
        translatedFunctionSignature: translatedFunctionSignature,
        methodName: javaName,
        parentName: parentName
      )

      // Closures.
      var funcTypes: [TranslatedFunctionType] = []
      for (idx, param) in decl.functionSignature.parameters.enumerated() {
        let parameterName = param.parameterName ?? "_\(idx)"

        switch param.type {
        case .function(let funcTy):
          let translatedClosure = try translateFunctionType(
            name: parameterName,
            swiftType: funcTy,
            parentName: parentName
          )
          funcTypes.append(translatedClosure)
        default:
          break
        }
      }

      return TranslatedFunctionDecl(
        name: javaName,
        nativeFunctionName: "$\(javaName)",
        parentName: parentName,
        functionTypes: funcTypes,
        translatedFunctionSignature: translatedFunctionSignature,
        nativeFunctionSignature: nativeFunctionSignature
      )
    }

    /// Translate Swift closure type to Java functional interface.
    func translateFunctionType(
      name: String,
      swiftType: SwiftFunctionType,
      parentName: String
    ) throws -> TranslatedFunctionType {
      var translatedParams: [TranslatedParameter] = []

      for (i, param) in swiftType.parameters.enumerated() {
        let paramName = param.parameterName ?? "_\(i)"
        translatedParams.append(
          try translateParameter(swiftType: param.type, parameterName: paramName, methodName: name, parentName: parentName)
        )
      }

      let transltedResult = try translate(swiftResult: SwiftResult(convention: .direct, type: swiftType.resultType))

      return TranslatedFunctionType(
        name: name,
        parameters: translatedParams,
        result: transltedResult,
        swiftType: swiftType
      )
    }

    func translate(
      functionSignature: SwiftFunctionSignature,
      methodName: String,
      parentName: String
    ) throws -> TranslatedFunctionSignature {
      let parameters = try functionSignature.parameters.enumerated().map { idx, param in
        let parameterName = param.parameterName ?? "arg\(idx))"
        return try translateParameter(swiftType: param.type, parameterName: parameterName, methodName: methodName, parentName: parentName)
      }

      // 'self'
      let selfParameter: TranslatedParameter?
      if case .instance(let swiftSelf) = functionSignature.selfParameter {
        selfParameter = try self.translateParameter(
          swiftType: swiftSelf.type,
          parameterName: swiftSelf.parameterName ?? "self",
          methodName: methodName,
          parentName: parentName
        )
      } else {
        selfParameter = nil
      }

      return try TranslatedFunctionSignature(
        selfParameter: selfParameter,
        parameters: parameters,
        resultType: translate(swiftResult: functionSignature.result)
      )
    }

    func translateParameter(
      swiftType: SwiftType,
      parameterName: String,
      methodName: String,
      parentName: String
    ) throws -> TranslatedParameter {
      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }
            return try translateOptionalParameter(
              wrappedType: genericArgs[0],
              parameterName: parameterName
            )

          default:
            guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType) else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            return TranslatedParameter(
              parameter: JavaParameter(name: parameterName, type: javaType),
              conversion: .placeholder
            )
          }
        }

        if nominalType.isJavaKitWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromJavaKitName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftType)
          }

          return TranslatedParameter(
            parameter: JavaParameter(
              name: parameterName,
              type: javaType
            ),
            conversion: .placeholder
          )
        }

        // We assume this is a JExtract class.
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .class(package: nil, name: nominalTypeName)
          ),
          conversion: .valueMemoryAddress(.placeholder)
        )

      case .tuple([]):
        return TranslatedParameter(
          parameter: JavaParameter(name: parameterName, type: .void),
          conversion: .placeholder
        )

      case .function:
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .class(package: javaPackage, name: "\(parentName).\(methodName).\(parameterName)")
          ),
          conversion: .placeholder
        )

      case .optional(let wrapped):
        return try translateOptionalParameter(
          wrappedType: wrapped,
          parameterName: parameterName
        )

      case .metatype, .tuple, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translateOptionalParameter(
      wrappedType swiftType: SwiftType,
      parameterName: String
    ) throws -> TranslatedParameter {
      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType) else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          let (translatedClass, orElseValue) = switch javaType {
          case .boolean: ("Optional<Boolean>", "false")
          case .byte: ("Optional<Byte>", "(byte) 0")
          case .char: ("Optional<Character>", "(char) 0")
          case .short: ("Optional<Short>", "(short) 0")
          case .int: ("OptionalInt", "0")
          case .long: ("OptionalLong", "0L")
          case .float: ("Optional<Float>", "0f")
          case .double: ("OptionalDouble", "0.0")
          case .javaLangString: ("Optional<String>", #""""#)
          default:
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          return TranslatedParameter(
            parameter: JavaParameter(
              name: parameterName,
              type: JavaType(className: translatedClass)
            ),
            conversion: .commaSeparated([
              .isOptionalPresent,
              .method(.placeholder, function: "orElse", arguments: [.constant(orElseValue)])
            ])
          )
        }

        guard !nominalType.isJavaKitWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
        }

        // Assume JExtract imported class
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .class(package: nil, name: "Optional<\(nominalTypeName)>")
          ),
          conversion: .method(
            .method(.placeholder, function: "map", arguments: [.constant("\(nominalType)::$memoryAddress")]),
            function: "orElse",
            arguments: [.constant("0L")]
          )
        )
      default:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translate(
      swiftResult: SwiftResult
    ) throws -> TranslatedResult {
      let swiftType = swiftResult.type

      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }
            return try translateOptionalResult(wrappedType: genericArgs[0])

          default:
            guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType) else {
              throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
            }

            return TranslatedResult(
              javaType: javaType,
              outParameters: [],
              conversion: .placeholder
            )
          }
        }

        if nominalType.isJavaKitWrapper {
          throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
        }

        // We assume this is a JExtract class.
        let javaType = JavaType.class(package: nil, name: nominalType.nominalTypeDecl.name)
        return TranslatedResult(
          javaType: javaType,
          outParameters: [],
          conversion: .constructSwiftValue(.placeholder, javaType)
        )

      case .tuple([]):
        return TranslatedResult(javaType: .void, outParameters: [], conversion: .placeholder)

      case .optional(let wrapped):
        return try translateOptionalResult(wrappedType: wrapped)

      case .metatype, .tuple, .function, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
      }
    }

    func translateOptionalResult(
      wrappedType swiftType: SwiftType
    ) throws -> TranslatedResult {
      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType) else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          let (returnType, optionalClass) = switch javaType {
          case .boolean: ("Optional<Boolean>", "Optional")
          case .byte: ("Optional<Byte>", "Optional")
          case .char: ("Optional<Character>", "Optional")
          case .short: ("Optional<Short>", "Optional")
          case .int: ("OptionalInt", "OptionalInt")
          case .long: ("OptionalLong", "OptionalLong")
          case .float: ("Optional<Float>", "Optional")
          case .double: ("OptionalDouble", "OptionalDouble")
          case .javaLangString: ("Optional<String>", "Optional")
          default:
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          // Check if we can fit the value and a discriminator byte in a primitive.
          // so the return JNI value will be (value || discriminator)
          if let nextIntergralTypeWithSpaceForByte = javaType.nextIntergralTypeWithSpaceForByte {
            return TranslatedResult(
              javaType: .class(package: nil, name: returnType),
              outParameters: [],
              conversion: .combinedValueToOptional(
                .placeholder,
                nextIntergralTypeWithSpaceForByte.java,
                valueType: javaType,
                valueSizeInBytes: nextIntergralTypeWithSpaceForByte.valueBytes,
                optionalType: optionalClass
              )
            )
          } else {
            // Otherwise, we return the result as normal, but
            // use an indirect return for the discriminator.
            return TranslatedResult(
              javaType: .class(package: nil, name: returnType),
              outParameters: [
                OutParameter(name: "result_discriminator$", type: .array(.byte), allocation: .newArray(.byte, size: 1))
              ],
              conversion: .toOptionalFromIndirectReturn(
                discriminatorName: "result_discriminator$",
                optionalClass: optionalClass,
                javaType: javaType,
                toValue: .placeholder
              )
            )
          }
        }

        guard !nominalType.isJavaKitWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
        }

        // We assume this is a JExtract class.
        let returnType = JavaType.class(package: nil, name: "Optional<\(nominalTypeName)>")
        return TranslatedResult(
          javaType: returnType,
          outParameters: [
            OutParameter(name: "result_discriminator$", type: .array(.byte), allocation: .newArray(.byte, size: 1))
          ],
          conversion: .toOptionalFromIndirectReturn(
            discriminatorName: "result_discriminator$",
            optionalClass: "Optional",
            javaType: .long,
            toValue: .constructSwiftValue(.placeholder, .class(package: nil, name: nominalTypeName))
          )
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }
  }

  struct TranslatedFunctionDecl {
    /// Java function name
    let name: String

    /// The name of the native function
    let nativeFunctionName: String

    /// The name of the Java parent scope this function is declared in
    let parentName: String

    /// Functional interfaces required for the Java method.
    let functionTypes: [TranslatedFunctionType]

    /// Function signature of the Java function the user will call
    let translatedFunctionSignature: TranslatedFunctionSignature

    /// Function signature of the native function that will be implemented by Swift
    let nativeFunctionSignature: NativeFunctionSignature
  }

  static func translate(knownType: SwiftKnownTypeDeclKind) -> JavaType? {
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

  struct TranslatedFunctionSignature {
    let selfParameter: TranslatedParameter?
    let parameters: [TranslatedParameter]
    let resultType: TranslatedResult

    var requiresSwiftArena: Bool {
      return self.resultType.conversion.requiresSwiftArena
    }
  }

  /// Represent a Swift API parameter translated to Java.
  struct TranslatedParameter {
    let parameter: JavaParameter
    let conversion: JavaNativeConversionStep
  }

  /// Represent a Swift API result translated to Java.
  struct TranslatedResult {
    let javaType: JavaType

    let outParameters: [OutParameter]

    /// Represents how to convert the Java native result into a user-facing result.
    let conversion: JavaNativeConversionStep
  }

  struct OutParameter {
    enum Allocation {
      case newArray(JavaType, size: Int)

      func render() -> String {
        switch self {
        case .newArray(let javaType, let size):
          "new \(javaType)[\(size)]"
        }
      }
    }

    let name: String
    let type: JavaType
    let allocation: Allocation

    var javaParameter: JavaParameter {
      JavaParameter(name: self.name, type: self.type)
    }
  }

  /// Represent a Swift closure type in the user facing Java API.
  ///
  /// Closures are translated to named functional interfaces in Java.
  struct TranslatedFunctionType {
    var name: String
    var parameters: [TranslatedParameter]
    var result: TranslatedResult
    var swiftType: SwiftFunctionType
  }

  /// Describes how to convert values between Java types and the native Java function
  enum JavaNativeConversionStep {
    /// The value being converted
    case placeholder

    case constant(String)

    // The input exploded into components.
    case explodedName(component: String)

    // Convert the results of the inner steps to a comma separated list.
    indirect case commaSeparated([JavaNativeConversionStep])

    /// `value.$memoryAddress()`
    indirect case valueMemoryAddress(JavaNativeConversionStep)

    /// Call `new \(Type)(\(placeholder), swiftArena$)`
    indirect case constructSwiftValue(JavaNativeConversionStep, JavaType)

    indirect case method(JavaNativeConversionStep, function: String, arguments: [JavaNativeConversionStep] = [])

    case isOptionalPresent

    indirect case combinedValueToOptional(JavaNativeConversionStep, JavaType, valueType: JavaType, valueSizeInBytes: Int, optionalType: String)

    indirect case ternary(JavaNativeConversionStep, thenExp: JavaNativeConversionStep, elseExp: JavaNativeConversionStep)

    indirect case equals(JavaNativeConversionStep, JavaNativeConversionStep)

    indirect case subscriptOf(JavaNativeConversionStep, arguments: [JavaNativeConversionStep])

    static func toOptionalFromIndirectReturn(
      discriminatorName: String,
      optionalClass: String,
      javaType: JavaType,
      toValue valueConversion: JavaNativeConversionStep
    ) -> JavaNativeConversionStep {
      .aggregate(
        name: "result$",
        type: javaType,
        [
          .ternary(
            .equals(
              .subscriptOf(.constant(discriminatorName), arguments: [.constant("0")]),
              .constant("1")
            ),
            thenExp: .method(.constant(optionalClass), function: "of", arguments: [valueConversion]),
            elseExp: .method(.constant(optionalClass), function: "empty")
          )
        ]
      )
    }

    /// Perform multiple conversions using the same input.
    case aggregate(name: String, type: JavaType, [JavaNativeConversionStep])

    /// Returns the conversion string applied to the placeholder.
    func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
      // NOTE: 'printer' is used if the conversion wants to cause side-effects.
      // E.g. storing a temporary values into a variable.
      switch self {
      case .placeholder:
        return placeholder

      case .constant(let value):
        return value

      case .explodedName(let component):
        return "\(placeholder)_\(component)"

      case .commaSeparated(let list):
        return list.map({ $0.render(&printer, placeholder)}).joined(separator: ", ")

      case .valueMemoryAddress:
        return "\(placeholder).$memoryAddress()"

      case .constructSwiftValue(let inner, let javaType):
        let inner = inner.render(&printer, placeholder)
        return "new \(javaType.className!)(\(inner), swiftArena$)"

      case .isOptionalPresent:
        return "(byte) (\(placeholder).isPresent() ? 1 : 0)"

      case .method(let inner, let methodName, let arguments):
        let inner = inner.render(&printer, placeholder)
        let args = arguments.map { $0.render(&printer, placeholder) }
        let argsStr = args.joined(separator: ", ")
        return "\(inner).\(methodName)(\(argsStr))"

      case .combinedValueToOptional(let combined, let combinedType, let valueType, let valueSizeInBytes, let optionalType):
        let combined = combined.render(&printer, placeholder)
        printer.print(
          """
          \(combinedType) combined$ = \(combined);
          byte discriminator$ = (byte) (combined$ & 0xFF);
          """
        )

        if valueType == .boolean {
          printer.print("boolean value$ = ((byte) (combined$ >> 8)) != 0;")
        } else {
          printer.print("\(valueType) value$ = (\(valueType)) (combined$ >> \(valueSizeInBytes * 8));")
        }

        return "discriminator$ == 1 ? \(optionalType).of(value$) : \(optionalType).empty()"

      case .ternary(let cond, let thenExp, let elseExp):
        let cond = cond.render(&printer, placeholder)
        let thenExp = thenExp.render(&printer, placeholder)
        let elseExp = elseExp.render(&printer, placeholder)
        return "(\(cond)) ? \(thenExp) : \(elseExp)"

      case .equals(let lhs, let rhs):
        let lhs = lhs.render(&printer, placeholder)
        let rhs = rhs.render(&printer, placeholder)
        return "\(lhs) == \(rhs)"

      case .subscriptOf(let inner, let arguments):
        let inner = inner.render(&printer, placeholder)
        let arguments = arguments.map { $0.render(&printer, placeholder) }
        return "\(inner)[\(arguments.joined(separator: ", "))]"

      case .aggregate(let name, let type, let steps):
        precondition(!steps.isEmpty, "Aggregate must contain steps")
        printer.print("\(type) \(name) = \(placeholder);")
        let steps = steps.map {
          $0.render(&printer, name)
        }
        return steps.last!
      }
    }

    /// Whether the conversion uses SwiftArena.
    var requiresSwiftArena: Bool {
      switch self {
      case .placeholder, .constant, .explodedName, .isOptionalPresent:
        return false

      case .constructSwiftValue:
        return true

      case .valueMemoryAddress(let inner):
        return inner.requiresSwiftArena

      case .commaSeparated(let list):
        return list.contains(where: { $0.requiresSwiftArena })

      case .method(let inner, _, let args):
        return inner.requiresSwiftArena || args.contains(where: \.requiresSwiftArena)

      case .combinedValueToOptional(let inner, _, _, _, _):
        return inner.requiresSwiftArena

      case .ternary(let cond, let thenExp, let elseExp):
        return cond.requiresSwiftArena || thenExp.requiresSwiftArena || elseExp.requiresSwiftArena

      case .equals(let lhs, let rhs):
        return lhs.requiresSwiftArena || rhs.requiresSwiftArena

      case .subscriptOf(let inner, _):
        return inner.requiresSwiftArena

      case .aggregate(_, _, let steps):
        return steps.contains(where: \.requiresSwiftArena)
      }
    }
  }

  enum JavaTranslationError: Error {
    case unsupportedSwiftType(SwiftType)

    /// The user has not supplied a mapping from `SwiftType` to
    /// a java class.
    case wrappedJavaClassTranslationNotProvided(SwiftType)
  }
}
