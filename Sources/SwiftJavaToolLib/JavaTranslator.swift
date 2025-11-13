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

import SwiftJava
import JavaLangReflect
import JavaTypes
import SwiftBasicFormat
import SwiftSyntax
import SwiftJavaConfigurationShared
import SwiftSyntaxBuilder
import Foundation
import Logging

/// Utility that translates Java classes into Swift source code to access
/// those Java classes.
package class JavaTranslator {
  let config: Configuration

  let log: Logger

  /// The name of the Swift module that we are translating into.
  let swiftModuleName: String

  let environment: JNIEnvironment

  /// Whether to translate Java classes into classes (rather than structs).
  let translateAsClass: Bool

  let format: BasicFormat

  /// A mapping from the name of each known Java class to the corresponding
  /// Swift type name and its Swift module.
  package var translatedClasses: [JavaFullyQualifiedTypeName: SwiftTypeName] = [
    "java.lang.Object": SwiftTypeName(module: "SwiftJava", name: "JavaObject"),
    "byte[]": SwiftTypeName(module: nil, name: "[UInt8]")
  ]

  /// A mapping from the name of each known Java class with the Swift value type
  /// (and its module) to which it is mapped.
  ///
  /// The Java classes here can also be part of `translatedClasses`. The entry in
  /// `translatedClasses` should map to a representation of the Java class (i.e.,
  /// an AnyJavaObject-conforming type) whereas the entry here should map to
  /// a value type.
  package let translatedToValueTypes: [JavaFullyQualifiedTypeName: SwiftTypeName] = [
    "java.lang.String": SwiftTypeName(module: "SwiftJava", name: "String"),
  ]

  /// The set of Swift modules that need to be imported to make the generated
  /// code compile. Use `getImportDecls()` to format this into a list of
  /// import declarations.
  package var importedSwiftModules: Set<String> = JavaTranslator.defaultImportedSwiftModules

  /// The canonical names of Java classes whose declared 'native'
  /// methods will be implemented in Swift.
  package var swiftNativeImplementations: Set<String> = []

  /// The set of nested classes that we should traverse from the given class,
  /// indexed by the name of the class.
  ///
  /// TODO: Make JavaClass Hashable so we can index by the object?
  package var nestedClasses: [String: [JavaClass<JavaObject>]] = [:]

  package init(
    config: Configuration,
    swiftModuleName: String,
    environment: JNIEnvironment,
    translateAsClass: Bool = false,
    format: BasicFormat = JavaTranslator.defaultFormat
  ) {
    self.config = config
    self.swiftModuleName = swiftModuleName
    self.environment = environment
    self.translateAsClass = translateAsClass
    self.format = format
    
    var l = Logger(label: "swift-java")
    l.logLevel = .init(rawValue: (config.logLevel ?? .info).rawValue)!
    self.log = l
  }

  /// Clear out any per-file state when we want to start a new file.
  package func startNewFile() {
    importedSwiftModules = Self.defaultImportedSwiftModules
  }

  /// Simplistic logging for all entities that couldn't be translated.
  func logUntranslated(_ message: String) {
    print("warning: \(message)")
  }
}

// MARK: Defaults
extension JavaTranslator {
  /// Default formatting options.
  private static let defaultFormat = BasicFormat(indentationWidth: .spaces(2))

  /// Default set of modules that will always be imported.
  private static let defaultImportedSwiftModules: Set<String> = [
    "SwiftJava",
    "CSwiftJavaJNI",
  ]
}

// MARK: Import translation
extension JavaTranslator {
  /// Retrieve the import declarations.
  package func getImportDecls() -> [DeclSyntax] {
    importedSwiftModules.filter {
      $0 != swiftModuleName
    }.sorted().map {
      "import \(raw: $0)\n"
    }
  }
}

// MARK: Type translation
extension JavaTranslator {

  func getSwiftReturnTypeNameAsString(
    method: JavaLangReflect.Method,
    preferValueTypes: Bool,
    outerOptional: OptionalKind
  ) throws -> String {
    let genericReturnType = method.getGenericReturnType()

    // Special handle the case when the return type is the generic type of the method: `<T> T foo()`

    return try getSwiftTypeNameAsString(
      method: method,
      genericReturnType!, 
      preferValueTypes: preferValueTypes, 
      outerOptional: outerOptional)
  }

  /// Turn a Java type into a string.
  func getSwiftTypeNameAsString(
    method: JavaLangReflect.Method? = nil,
    _ javaType: Type,
    preferValueTypes: Bool,
    outerOptional: OptionalKind
  ) throws -> String {
    // Replace type variables with their bounds.
    if let typeVariable = javaType.as(TypeVariable<GenericDeclaration>.self),
      typeVariable.getBounds().count == 1,
      let bound = typeVariable.getBounds()[0]
    {
      return outerOptional.adjustTypeName(typeVariable.getName())
    }

    // Replace wildcards with their upper bound.
    if let wildcardType = javaType.as(WildcardType.self),
      wildcardType.getUpperBounds().count == 1,
      let bound = wildcardType.getUpperBounds()[0]
    {
      // Replace a wildcard type with its first bound.
      return try getSwiftTypeNameAsString(
        bound,
        preferValueTypes: preferValueTypes,
        outerOptional: outerOptional
      )
    }

    // Handle array types by recursing into the component type.
    if let arrayType = javaType.as(GenericArrayType.self) {
      if preferValueTypes {
        let elementType = try getSwiftTypeNameAsString(
          arrayType.getGenericComponentType()!,
          preferValueTypes: preferValueTypes,
          outerOptional: .optional
        )
        return "[\(elementType)]"
      }

      let (swiftName, _) = try getSwiftTypeName(
        JavaClass<JavaArray>().as(JavaClass<JavaObject>.self)!,
        preferValueTypes: false
      )

      return outerOptional.adjustTypeName(swiftName)
    }

    // Handle parameterized types by recursing on the raw type and the type
    // arguments.
    if let parameterizedType = javaType.as(ParameterizedType.self) {
      if let rawJavaType = parameterizedType.getRawType() {
        var rawSwiftType = try getSwiftTypeNameAsString(
          rawJavaType,
          preferValueTypes: false,
          outerOptional: outerOptional
        )

        let optionalSuffix: String
        if let lastChar = rawSwiftType.last, lastChar == "?" || lastChar == "!" {
          optionalSuffix = "\(lastChar)"
          rawSwiftType.removeLast()
        } else {
          optionalSuffix = ""
        }

        let typeArguments: [String] = try parameterizedType.getActualTypeArguments().compactMap { typeArg in
          guard let typeArg else { return nil }
          
          let mappedSwiftName = try getSwiftTypeNameAsString(method: method, typeArg, preferValueTypes: false, outerOptional: .nonoptional)

          // FIXME: improve the get instead...
          if mappedSwiftName == nil || mappedSwiftName == "JavaObject" {
            // Try to salvage it, is it perhaps a type parameter?
            if let method {
              if method.getTypeParameters().contains(where: { $0?.getTypeName() == typeArg.getTypeName() }) {
                return typeArg.getTypeName()
              }
            }
          }

          return mappedSwiftName
        }

        return "\(rawSwiftType)<\(typeArguments.joined(separator: ", "))>\(optionalSuffix)"
      }
    }

    // Handle direct references to Java classes.
    guard let javaClass = javaType.as(JavaClass<JavaObject>.self) else {
      throw TranslationError.unhandledJavaType(javaType)
    }

    let (swiftName, isOptional) = try getSwiftTypeName(javaClass, preferValueTypes: preferValueTypes)
    let resultString =
      if isOptional {
         outerOptional.adjustTypeName(swiftName)
      } else {
        swiftName
      }
    return resultString
  }

  /// Translate a Java class into its corresponding Swift type name.
  package func getSwiftTypeName(
    _ javaClass: JavaClass<JavaObject>,
    preferValueTypes: Bool
  ) throws -> (swiftName: String, isOptional: Bool) {
    let javaType = try JavaType(javaTypeName: javaClass.getName())
    let isSwiftOptional = javaType.isSwiftOptional(stringIsValueType: preferValueTypes)

    let swiftTypeName: String
    if !preferValueTypes, case .array(_) = javaType {
      swiftTypeName = try self.getSwiftTypeNameFromJavaClassName("java.lang.reflect.Array", preferValueTypes: false)
    } else {
      swiftTypeName = try javaType.swiftTypeName { javaClassName in
        try self.getSwiftTypeNameFromJavaClassName(javaClassName, preferValueTypes: preferValueTypes)
      }
    }

    return (swiftTypeName, isSwiftOptional)
  }

  /// Map a Java class name to its corresponding Swift type.
  func getSwiftTypeNameFromJavaClassName(
    _ name: String,
    preferValueTypes: Bool,
    escapeMemberNames: Bool = true
  ) throws -> String {
    // If we want a value type, look for one.
    if preferValueTypes, let translatedValueType = translatedToValueTypes[name] {
      // Note that we need to import this Swift module.
      if translatedValueType.swiftModule != swiftModuleName {
        guard let module = translatedValueType.swiftModule else { 
          preconditionFailure("Translated value type must have Swift module, but was nil! Type: \(translatedValueType)")
        }
        importedSwiftModules.insert(module)
      }

      return translatedValueType.swiftType
    }

    if let translated = translatedClasses[name] {
      // Note that we need to import this Swift module.
      if let swiftModule = translated.swiftModule, swiftModule != swiftModuleName {
        importedSwiftModules.insert(swiftModule)
      }

      if escapeMemberNames {
        return translated.swiftType.escapingSwiftMemberNames
      }

      return translated.swiftType
    }

    throw TranslationError.untranslatedJavaClass(name)
  }
}

// MARK: Class translation
extension JavaTranslator {
  /// Translates the given Java class into the corresponding Swift type. This
  /// can produce multiple declarations, such as a separate extension of
  /// JavaClass to house static methods.
  package func translateClass(_ javaClass: JavaClass<JavaObject>) throws -> [DeclSyntax] {
    return try JavaClassTranslator(javaClass: javaClass, translator: self).render()
  }
}

extension String {
  /// Escape Swift types that involve member name references like '.Type'
  fileprivate var escapingSwiftMemberNames: String {
    var count = 0
    return split(separator: ".").map { component in
      defer {
        count += 1
      }

      if count > 0 && component.memberRequiresBackticks {
        return "`\(component)`"
      }

      return String(component)
    }.joined(separator: ".")
  }
}

extension Substring {
  fileprivate var memberRequiresBackticks: Bool {
    switch self {
    case "Type": return true
    default: return false
    }
  }
}
