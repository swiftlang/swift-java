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

import JavaKit
import JavaKitReflection
import JavaTypes
import SwiftBasicFormat
import SwiftSyntax
import SwiftSyntaxBuilder

/// Utility that translates Java classes into Swift source code to access
/// those Java classes.
class JavaTranslator {
  /// The name of the Swift module that we are translating into.
  let swiftModuleName: String

  let environment: JNIEnvironment
  let format: BasicFormat

  /// A mapping from the canonical name of Java classes to the corresponding
  /// Swift type name, its Swift module, and whether we need to be working
  /// with optionals.
  ///
  /// FIXME: This is currently prepopulated with known translated classes,
  /// which is absolutely not scalable. We need a better way to be able to
  /// discover already-translated Java classes to get their corresponding
  /// Swift types and modules.
  var translatedClasses: [String: (swiftType: String, swiftModule: String?, isOptional: Bool)] =
    defaultTranslatedClasses

  /// The set of Swift modules that need to be imported to make the generated
  /// code compile. Use `getImportDecls()` to format this into a list of
  /// import declarations.
  var importedSwiftModules: Set<String> = JavaTranslator.defaultImportedSwiftModules

  /// The manifest for the module being translated.
  var manifest: TranslationManifest

  init(
    swiftModuleName: String,
    environment: JNIEnvironment,
    format: BasicFormat = JavaTranslator.defaultFormat
  ) {
    self.swiftModuleName = swiftModuleName
    self.environment = environment
    self.format = format
    self.manifest = TranslationManifest(swiftModule: swiftModuleName)
  }

  /// Clear out any per-file state when we want to start a new file.
  func startNewFile() {
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
    "JavaKit",
    "JavaRuntime",
  ]

  /// The default set of translated classes that do not come from JavaKit
  /// itself. This should only be used to refer to types that are built-in to
  /// JavaKit and therefore aren't captured in any manifest.
  private static let defaultTranslatedClasses: [String: (swiftType: String, swiftModule: String?, isOptional: Bool)] = [
    "java.lang.Class": ("JavaClass", "JavaKit", true),
    "java.lang.String": ("String", "JavaKit", false),
  ]
}

// MARK: Import translation
extension JavaTranslator {
  /// Retrieve the import declarations.
  func getImportDecls() -> [DeclSyntax] {
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
  func getSwiftTypeNameAsString(_ javaType: Type, outerOptional: Bool) throws -> String {
    // Replace type variables with their bounds.
    if let typeVariable = javaType.as(TypeVariable<GenericDeclaration>.self),
      typeVariable.getBounds().count == 1,
      let bound = typeVariable.getBounds()[0]
    {
      return try getSwiftTypeNameAsString(bound, outerOptional: outerOptional)
    }

    // Replace wildcards with their upper bound.
    if let wildcardType = javaType.as(WildcardType.self),
      wildcardType.getUpperBounds().count == 1,
      let bound = wildcardType.getUpperBounds()[0]
    {
      // Replace a wildcard type with its first bound.
      return try getSwiftTypeNameAsString(bound, outerOptional: outerOptional)
    }

    // Handle array types by recursing into the component type.
    if let arrayType = javaType.as(GenericArrayType.self) {
      let elementType = try getSwiftTypeNameAsString(arrayType.getGenericComponentType()!, outerOptional: true)
      return "[\(elementType)]"
    }

    // Handle parameterized types by recursing on the raw type and the type
    // arguments.
    if let parameterizedType = javaType.as(ParameterizedType.self),
      let rawJavaType = parameterizedType.getRawType()
    {
      var rawSwiftType = try getSwiftTypeNameAsString(rawJavaType, outerOptional: outerOptional)

      let makeOptional: Bool
      if rawSwiftType.last == "?" {
        makeOptional = true
        rawSwiftType.removeLast()
      } else {
        makeOptional = false
      }

      let typeArguments = try parameterizedType.getActualTypeArguments().compactMap { typeArg in
        try typeArg.map { typeArg in
          try getSwiftTypeNameAsString(typeArg, outerOptional: false)
        }
      }

      return "\(rawSwiftType)<\(typeArguments.joined(separator: ", "))>\(makeOptional ? "?" : "")"
    }

    // Handle direct references to Java classes.
    guard let javaClass = javaType.as(JavaClass<JavaObject>.self) else {
      throw TranslationError.unhandledJavaType(javaType)
    }

    let (swiftName, isOptional) = try getSwiftTypeName(javaClass)
    var resultString = swiftName
    if isOptional && outerOptional {
      resultString += "?"
    }
    return resultString
  }

  /// Translate a Java class into its corresponding Swift type name.
  func getSwiftTypeName(_ javaClass: JavaClass<JavaObject>) throws -> (swiftName: String, isOptional: Bool) {
    let javaType = try JavaType(javaTypeName: javaClass.getName())
    let isSwiftOptional = javaType.isSwiftOptional
    return (
      try javaType.swiftTypeName(resolver: self.getSwiftTypeNameFromJavaClassName(_:)),
      isSwiftOptional
    )
  }

  /// Map a Java class name to its corresponding Swift type.
  private func getSwiftTypeNameFromJavaClassName(_ name: String) throws -> String {
    if let translated = translatedClasses[name] {
      // Note that we need to import this Swift module.
      if let swiftModule = translated.swiftModule, swiftModule != swiftModuleName {
        importedSwiftModules.insert(swiftModule)
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
  func translateClass(_ javaClass: JavaClass<JavaObject>) -> [DeclSyntax] {
    let fullName = javaClass.getCanonicalName()
    let swiftTypeName = try! getSwiftTypeNameFromJavaClassName(fullName)

    // Record this translated class into the manifest.
    manifest.translatedClasses[fullName] = swiftTypeName

    // Superclass.
    let extends: String
    if !javaClass.isInterface(),
      let superclass = javaClass.getSuperclass(),
      superclass.getCanonicalName() != "java.lang.Object"
    {
      do {
        extends = ", extends: \(try getSwiftTypeName(superclass).swiftName).self"
      } catch {
        logUntranslated("Unable to translate '\(fullName)' superclass: \(error)")
        extends = ""
      }
    } else {
      extends = ""
    }

    // The set of generic interfaces implemented by a class or
    // extended by an interface.
    let interfaces: [String] = javaClass.getGenericInterfaces().compactMap { javaType in
      guard let javaType else {
        return nil
      }

      do {
        let typeName = try getSwiftTypeNameAsString(javaType, outerOptional: false)
        return "\(typeName).self"
      } catch {
        logUntranslated("Unable to translate '\(fullName)' interface '\(javaType.getTypeName())': \(error)")
        return nil
      }
    }
    let interfacesStr: String
    if interfaces.isEmpty {
      interfacesStr = ""
    } else {
      let prefix = javaClass.isInterface() ? "extends" : "implements"
      interfacesStr = ", \(prefix): \(interfaces.joined(separator: ", "))"
    }

    // Members
    var members: [DeclSyntax] = []

    // Constructors
    members.append(
      contentsOf: javaClass.getConstructors().compactMap {
        $0.flatMap { constructor in
          do {
            return try translateConstructor(constructor)
          } catch {
            logUntranslated("Unable to translate '\(fullName)' constructor: \(error)")
            return nil
          }
        }
      }
    )

    // Methods
    var staticMethods: [Method] = []
    members.append(
      contentsOf: javaClass.getMethods().compactMap {
        $0.flatMap { method in
          // Save the static methods; they need to go on an extension of
          // JavaClass.
          if method.isStatic {
            staticMethods.append(method)
            return nil
          }

          // Translate the method if we can.
          do {
            return try translateMethod(method)
          } catch {
            logUntranslated("Unable to translate '\(fullName)' method '\(method.getName())': \(error)")
            return nil
          }
        }
      }
    )

    // Map the generic parameters.
    let genericParameterClause: String
    let staticMemberWhereClause: String
    let javaTypeParameters = javaClass.getTypeParameters()
    if !javaTypeParameters.isEmpty {
      let genericParameterNames = javaTypeParameters.compactMap { typeVar in
        typeVar?.getName()
      }

      let genericParameters = genericParameterNames.map { name in
        "\(name): AnyJavaObject"
      }

      genericParameterClause = "<\(genericParameters.joined(separator: ", "))>"
      let genericArgumentClause = "<\(genericParameterNames.joined(separator: ", "))>"

      staticMemberWhereClause = " where ObjectType == \(swiftTypeName)\(genericArgumentClause)"
    } else {
      genericParameterClause = ""
      staticMemberWhereClause = ""
    }

    // Emit the struct declaration describing the java class.
    let (swiftParentType, swiftInnermostTypeName) = swiftTypeName.splitSwiftTypeName()
    let classOrInterface: String = javaClass.isInterface() ? "JavaInterface" : "JavaClass";
    var classDecl =
      """
      @\(raw:classOrInterface)(\(literal: fullName)\(raw: extends)\(raw: interfacesStr))
      public struct \(raw: swiftInnermostTypeName)\(raw: genericParameterClause) {
      \(raw: members.map { $0.description }.joined(separator: "\n\n"))
      }
      """ as DeclSyntax

    // If there is a parent type, wrap this type up in an extension of that
    // parent type.
    if let swiftParentType {
      classDecl =
        """
        extension \(raw: swiftParentType) {
          \(classDecl)
        }
        """
    }

    // Format the class declaration.
    classDecl = classDecl.formatted(using: format).cast(DeclSyntax.self)

    if staticMethods.isEmpty {
      return [classDecl]
    }

    // Translate static members.
    var staticMembers: [DeclSyntax] = []
    staticMembers.append(
      contentsOf: javaClass.getMethods().compactMap {
        $0.flatMap { method in
          // Skip the instance methods; they were handled above.
          if !method.isStatic {
            return nil
          }

          // Translate each static method.
          do {
            return try translateMethod(
              method,
              genericParameterClause: genericParameterClause,
              whereClause: staticMemberWhereClause
            )
          } catch {
            logUntranslated("Unable to translate '\(fullName)' static method '\(method.getName())': \(error)")
            return nil
          }
        }
      }
    )

    if staticMembers.isEmpty {
      return [classDecl]
    }

    // Specify the specialization arguments when needed.
    let extSpecialization: String
    if genericParameterClause.isEmpty {
      extSpecialization = "<\(swiftTypeName)>"
    } else {
      extSpecialization = ""
    }

    let extDecl =
      ("""
    extension JavaClass\(raw: extSpecialization) {
    \(raw: staticMembers.map { $0.description }.joined(separator: "\n\n"))
    }
    """ as DeclSyntax).formatted(using: format).cast(DeclSyntax.self)

    return [classDecl, extDecl]
  }
}

// MARK: Method and constructor translation
extension JavaTranslator {
  /// Translates the given Java constructor into a Swift declaration.
  func translateConstructor(_ javaConstructor: Constructor<some AnyJavaObject>) throws -> DeclSyntax {
    let parameters = try translateParameters(javaConstructor.getParameters()) + ["environment: JNIEnvironment"]
    let parametersStr = parameters.map { $0.description }.joined(separator: ", ")
    let throwsStr = javaConstructor.throwsCheckedException ? "throws" : ""

    return """
      @JavaMethod
      public init(\(raw: parametersStr))\(raw: throwsStr)
      """
  }

  /// Translates the given Java method into a Swift declaration.
  func translateMethod(
    _ javaMethod: Method,
    genericParameterClause: String = "",
    whereClause: String = ""
  ) throws -> DeclSyntax {
    // Map the parameters.
    let parameters = try translateParameters(javaMethod.getParameters())

    let parametersStr = parameters.map { $0.description }.joined(separator: ", ")

    // Map the result type.
    let resultTypeStr: String
    let resultType = try getSwiftTypeNameAsString(javaMethod.getGenericReturnType()!, outerOptional: true)
    if resultType != "Void" {
      resultTypeStr = " -> \(resultType)"
    } else {
      resultTypeStr = ""
    }

    let throwsStr = javaMethod.throwsCheckedException ? "throws" : ""

    let methodAttribute: AttributeSyntax = javaMethod.isStatic ? "@JavaStaticMethod" : "@JavaMethod";
    return """
      \(methodAttribute)
      public func \(raw: javaMethod.getName())\(raw: genericParameterClause)(\(raw: parametersStr))\(raw: throwsStr)\(raw: resultTypeStr)\(raw: whereClause)
      """
  }

  // Translate a Java parameter list into Swift parameters.
  private func translateParameters(_ parameters: [Parameter?]) throws -> [FunctionParameterSyntax] {
    return try parameters.compactMap { javaParameter in
      guard let javaParameter else { return nil }

      let typeName = try getSwiftTypeNameAsString(javaParameter.getParameterizedType()!, outerOptional: true)
      let paramName = javaParameter.getName()
      return "_ \(raw: paramName): \(raw: typeName)"
    }
  }
}
