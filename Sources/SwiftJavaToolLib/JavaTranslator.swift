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
import SwiftBasicFormat
import SwiftSyntax
import SwiftJavaConfigurationShared
import SwiftSyntaxBuilder

/// Utility that translates Java classes into Swift source code to access
/// those Java classes.
package class JavaTranslator {
  /// The name of the Swift module that we are translating into.
  let swiftModuleName: String

  let environment: JNIEnvironment

  /// Whether to translate Java classes into classes (rather than structs).
  let translateAsClass: Bool

  let format: BasicFormat

  /// A mapping from the name of each known Java class to the corresponding
  /// Swift type name and its Swift module.
  package var translatedClasses: [String: (swiftType: String, swiftModule: String?)] = [:]

  /// A mapping from the name of each known Java class with the Swift value type
  /// (and its module) to which it is mapped.
  ///
  /// The Java classes here can also be part of `translatedClasses`. The entry in
  /// `translatedClasses` should map to a representation of the Java class (i.e.,
  /// an AnyJavaObject-conforming type) whereas the entry here should map to
  /// a value type.
  package let translatedToValueTypes: [String: (swiftType: String, swiftModule: String) ] = [
    "java.lang.String": ("String", "SwiftJava"),
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
    swiftModuleName: String,
    environment: JNIEnvironment,
    translateAsClass: Bool = false,
    format: BasicFormat = JavaTranslator.defaultFormat
  ) {
    self.swiftModuleName = swiftModuleName
    self.environment = environment
    self.translateAsClass = translateAsClass
    self.format = format
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
  /// Turn a Java type into a string.
  func getSwiftTypeNameAsString(
    _ javaType: Type,
    preferValueTypes: Bool,
    outerOptional: OptionalKind
  ) throws -> String {
    // Replace type variables with their bounds.
    if let typeVariable = javaType.as(TypeVariable<GenericDeclaration>.self),
      typeVariable.getBounds().count == 1,
      let bound = typeVariable.getBounds()[0]
    {
      return try getSwiftTypeNameAsString(
        bound,
        preferValueTypes: preferValueTypes,
        outerOptional: outerOptional
      )
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
    if let parameterizedType = javaType.as(ParameterizedType.self),
      let rawJavaType = parameterizedType.getRawType()
    {
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

      let typeArguments = try parameterizedType.getActualTypeArguments().compactMap { typeArg in
        try typeArg.map { typeArg in
          try getSwiftTypeNameAsString(typeArg, preferValueTypes: false, outerOptional: .nonoptional)
        }
      }

      return "\(rawSwiftType)<\(typeArguments.joined(separator: ", "))>\(optionalSuffix)"
    }

    // Handle direct references to Java classes.
    guard let javaClass = javaType.as(JavaClass<JavaObject>.self) else {
      throw TranslationError.unhandledJavaType(javaType)
    }

    let (swiftName, isOptional) = try getSwiftTypeName(javaClass, preferValueTypes: preferValueTypes)
    var resultString = swiftName
    if isOptional {
      resultString = outerOptional.adjustTypeName(resultString)
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
        importedSwiftModules.insert(translatedValueType.swiftModule)
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
