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
package class JavaTranslator {
  /// The name of the Swift module that we are translating into.
  let swiftModuleName: String

  let environment: JNIEnvironment
  let format: BasicFormat

  /// A mapping from the canonical name of Java classes to the corresponding
  /// Swift type name, its Swift module, and whether we need to be working
  /// with optionals.
  package var translatedClasses: [String: (swiftType: String, swiftModule: String?, isOptional: Bool)] =
    defaultTranslatedClasses

  /// The set of Swift modules that need to be imported to make the generated
  /// code compile. Use `getImportDecls()` to format this into a list of
  /// import declarations.
  package var importedSwiftModules: Set<String> = JavaTranslator.defaultImportedSwiftModules

  /// The canonical names of Java classes whose declared 'native'
  /// methods will be implemented in Swift.
  package var swiftNativeImplementations: Set<String> = []

  package init(
    swiftModuleName: String,
    environment: JNIEnvironment,
    format: BasicFormat = JavaTranslator.defaultFormat
  ) {
    self.swiftModuleName = swiftModuleName
    self.environment = environment
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
    "JavaKit",
    "JavaRuntime",
  ]

  /// The default set of translated classes that do not come from JavaKit
  /// itself. This should only be used to refer to types that are built-in to
  /// JavaKit and therefore aren't captured in any configuration file.
  package static let defaultTranslatedClasses: [String: (swiftType: String, swiftModule: String?, isOptional: Bool)] = [
    "java.lang.Class": ("JavaClass", "JavaKit", true),
    "java.lang.String": ("String", "JavaKit", false),
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
  package func getSwiftTypeName(_ javaClass: JavaClass<JavaObject>) throws -> (swiftName: String, isOptional: Bool) {
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
  package func translateClass(_ javaClass: JavaClass<JavaObject>) -> [DeclSyntax] {
    let fullName = javaClass.getCanonicalName()
    let swiftTypeName = try! getSwiftTypeNameFromJavaClassName(fullName)

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

    // The top-level declarations we will be returning.
    var topLevelDecls: [DeclSyntax] = []

    // Members
    var members: [DeclSyntax] = []

    // Members that are native and will instead go into a NativeMethods
    // protocol.
    var nativeMembers: [DeclSyntax] = []

    // Fields
    var staticFields: [Field] = []
    var enumConstants: [Field] = []
    members.append(
      contentsOf: javaClass.getFields().compactMap {
        $0.flatMap { field in
          if field.isStatic {
            staticFields.append(field)

            if field.isEnumConstant() {
              enumConstants.append(field)
            }
            return nil
          }
          
          do {
            return try translateField(field)
          } catch {
            logUntranslated("Unable to translate '\(fullName)' static field '\(field.getName())': \(error)")
            return nil
          }
        }
      }
    )

    if !enumConstants.isEmpty {
      let enumName = "\(swiftTypeName)Cases"
      members.append(
        contentsOf: translateToEnumValue(name: enumName, enumFields: enumConstants)
      )
    }

    // Constructors
    members.append(
      contentsOf: javaClass.getConstructors().compactMap {
        $0.flatMap { constructor in
          do {
            let implementedInSwift = constructor.isNative &&
              constructor.getDeclaringClass()!.equals(javaClass.as(JavaObject.self)!) &&
              swiftNativeImplementations.contains(javaClass.getCanonicalName())

            let translated = try translateConstructor(
              constructor,
              implementedInSwift: implementedInSwift
            )

            if implementedInSwift {
              nativeMembers.append(translated)
              return nil
            }

            return translated
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
        $0.flatMap { (method) -> DeclSyntax? in
          // Save the static methods; they need to go on an extension of
          // JavaClass.
          if method.isStatic {
            staticMethods.append(method)
            return nil
          }

          let implementedInSwift = method.isNative &&
            method.getDeclaringClass()!.equals(javaClass.as(JavaObject.self)!) &&
            swiftNativeImplementations.contains(javaClass.getCanonicalName())

          // Translate the method if we can.
          do {
            let translated = try translateMethod(
              method,
              implementedInSwift: implementedInSwift
            )

            if implementedInSwift {
              nativeMembers.append(translated)
              return nil
            }

            return translated
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

    topLevelDecls.append(classDecl)

    // Translate static members.
    var staticMembers: [DeclSyntax] = []

    staticMembers.append(
      contentsOf: staticFields.compactMap { field in
        // Translate each static field.
        do {
          return try translateField(field)
        } catch {
          logUntranslated("Unable to translate '\(fullName)' field '\(field.getName())': \(error)")
          return nil
        }
      }
    )
    
    staticMembers.append(
      contentsOf: staticMethods.compactMap { method in
          // Translate each static method.
          do {
            return try translateMethod(
              method, implementedInSwift: /*FIXME:*/false,
              genericParameterClause: genericParameterClause,
              whereClause: staticMemberWhereClause
            )
          } catch {
            logUntranslated("Unable to translate '\(fullName)' static method '\(method.getName())': \(error)")
            return nil
          }
        }
    )

    if !staticMembers.isEmpty {
      // Specify the specialization arguments when needed.
      let extSpecialization: String
      if genericParameterClause.isEmpty {
        extSpecialization = "<\(swiftTypeName)>"
      } else {
        extSpecialization = ""
      }

      let extDecl: DeclSyntax =
        """
        extension JavaClass\(raw: extSpecialization) {
        \(raw: staticMembers.map { $0.description }.joined(separator: "\n\n"))
        }
        """

      topLevelDecls.append(
        extDecl.formatted(using: format).cast(DeclSyntax.self)
      )
    }

    if !nativeMembers.isEmpty {
      let protocolDecl: DeclSyntax =
        """
        /// Describes the Java `native` methods for ``\(raw: swiftTypeName)``.
        ///
        /// To implement all of the `native` methods for \(raw: swiftTypeName) in Swift,
        /// extend \(raw: swiftTypeName) to conform to this protocol and mark
        /// each implementation of the protocol requirement with
        /// `@JavaMethod`.
        protocol \(raw: swiftTypeName)NativeMethods {
          \(raw: nativeMembers.map { $0.description }.joined(separator: "\n\n"))
        }
        """

      topLevelDecls.append(
        protocolDecl.formatted(using: format).cast(DeclSyntax.self)
      )
    }

    return topLevelDecls
  }
}

// MARK: Method and constructor translation
extension JavaTranslator {
  /// Translates the given Java constructor into a Swift declaration.
  package func translateConstructor(
    _ javaConstructor: Constructor<some AnyJavaObject>,
    implementedInSwift: Bool
  ) throws -> DeclSyntax {
    let parameters = try translateParameters(javaConstructor.getParameters()) + ["environment: JNIEnvironment? = nil"]
    let parametersStr = parameters.map { $0.description }.joined(separator: ", ")
    let throwsStr = javaConstructor.throwsCheckedException ? "throws" : ""

    let javaMethodAttribute = implementedInSwift
      ? ""
      : "@JavaMethod\n"
    let accessModifier = implementedInSwift ? "" : "public "
    return """
      \(raw: javaMethodAttribute)\(raw: accessModifier)init(\(raw: parametersStr))\(raw: throwsStr)
      """
  }

  /// Translates the given Java method into a Swift declaration.
  package func translateMethod(
    _ javaMethod: Method,
    implementedInSwift: Bool,
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
    let swiftMethodName = javaMethod.getName().escapedSwiftName
    let methodAttribute: AttributeSyntax = implementedInSwift
      ? ""
      : javaMethod.isStatic ? "@JavaStaticMethod\n" : "@JavaMethod\n";
    let accessModifier = implementedInSwift ? "" : "public "
    return """
      \(methodAttribute)\(raw: accessModifier)func \(raw: swiftMethodName)\(raw: genericParameterClause)(\(raw: parametersStr))\(raw: throwsStr)\(raw: resultTypeStr)\(raw: whereClause)
      """
  }
    
  package func translateField(_ javaField: Field) throws -> DeclSyntax {
    let typeName = try getSwiftTypeNameAsString(javaField.getGenericType()!, outerOptional: true)
    let fieldAttribute: AttributeSyntax = javaField.isStatic ? "@JavaStaticField" : "@JavaField";
    let swiftFieldName = javaField.getName().escapedSwiftName
    return """
      \(fieldAttribute)
      public var \(raw: swiftFieldName): \(raw: typeName)
      """
  }

  package func translateToEnumValue(name: String, enumFields: [Field]) -> [DeclSyntax] {
    let extensionSyntax: DeclSyntax = """
      public enum \(raw: name): Equatable {
        \(raw: enumFields.map { "case \($0.getName())" }.joined(separator: "\n"))
      }
    """

    let mappingSyntax: DeclSyntax = """
      public var enumValue: \(raw: name)? {
        let classObj = self.javaClass
        \(raw: enumFields.map {
          // The equals method takes a java object, so we need to cast it here
          """
          if self.equals(classObj.\($0.getName())?.as(JavaObject.self)) {
                return \(name).\($0.getName())
          }
          """
        }.joined(separator: " else ")) else {
          return nil
        }
      }
    """

    let initSyntax: DeclSyntax = """
    public init(_ enumValue: \(raw: name), environment: JNIEnvironment? = nil) {
      let _environment = if let environment {
        environment
      } else {
        try! JavaVirtualMachine.shared().environment()
      }
      let classObj = try! JavaClass<Self>(in: _environment)
      switch enumValue {
    \(raw: enumFields.map {
      return """
          case .\($0.getName()):
            if let \($0.getName()) = classObj.\($0.getName()) {
              self = \($0.getName())
            } else {
              fatalError("Enum value \($0.getName()) was unexpectedly nil, please re-run Java2Swift on the most updated Java class") 
            }
      """
    }.joined(separator: "\n"))
      }
    }
    """

    return [extensionSyntax, mappingSyntax, initSyntax]
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
