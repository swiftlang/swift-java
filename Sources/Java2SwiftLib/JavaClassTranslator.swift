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
import SwiftSyntax

/// Utility type that translates a single Java class into its corresponding
/// Swift type and any additional helper types or functions.
struct JavaClassTranslator {
  /// The translator we are working with, which provides global knowledge
  /// needed for translation.
  let translator: JavaTranslator

  /// The Java class (or interface) being translated.
  let javaClass: JavaClass<JavaObject>

  /// The type parameters to the Java class or interface.
  let javaTypeParameters: [TypeVariable<JavaClass<JavaObject>>]

  /// The set of nested classes of this class that will be rendered along
  /// with it.
  let nestedClasses: [JavaClass<JavaObject>]

  /// The full name of the Swift type that will be generated for this Java
  /// class.
  let swiftTypeName: String

  /// The Swift name of the superclass.
  let swiftSuperclass: String?

  /// The Swift names of the interfaces that this class implements.
  let swiftInterfaces: [String]

  /// The (instance) fields of the Java class.
  var fields: [Field] = []

  /// The static fields of the Java class.
  var staticFields: [Field] = []

  /// Enum constants of the Java class, which are also static fields and are
  /// reflected additionally as enum cases.
  var enumConstants: [Field] = []

  /// Constructors of the Java class.
  var constructors: [Constructor<JavaObject>] = []

  /// The (instance) methods of the Java class.
  var methods: MethodCollector = MethodCollector()

  /// The static methods of the Java class.
  var staticMethods: MethodCollector = MethodCollector()

  /// The native instance methods of the Java class, which are also reflected
  /// in a `*NativeMethods` protocol so they can be implemented in Swift.
  var nativeMethods: [Method] = []

  /// The native static methods of the Java class.
  /// TODO: These are currently unimplemented.
  var nativeStaticMethods: [Method] = []

  /// Whether the Java class we're translating is actually an interface.
  var isInterface: Bool {
    return javaClass.isInterface()
  }

  /// The name of the enclosing Swift type, if there is one.
  var swiftParentType: String? {
    swiftTypeName.splitSwiftTypeName().parentType
  }

  /// The name of the innermost Swift type, without the enclosing type.
  var swiftInnermostTypeName: String {
    swiftTypeName.splitSwiftTypeName().name
  }

  /// The generic parameter clause for the Swift version of the Java class.
  var genericParameterClause: String {
    if javaTypeParameters.isEmpty {
      return ""
    }

    let genericParameters = javaTypeParameters.map { param in
      "\(param.getName()): AnyJavaObject"
    }

    return "<\(genericParameters.joined(separator: ", "))>"
  }

  /// Prepare translation for the given Java class (or interface).
  init(javaClass: JavaClass<JavaObject>, translator: JavaTranslator) throws {
    let fullName = javaClass.getName()
    self.javaClass = javaClass
    self.translator = translator
    self.swiftTypeName = try translator.getSwiftTypeNameFromJavaClassName(fullName, escapeMemberNames: false)

    // Type parameters.
    self.javaTypeParameters = javaClass.getTypeParameters().compactMap { $0 }
    self.nestedClasses = translator.nestedClasses[fullName] ?? []

    // Superclass.
    if !javaClass.isInterface(),
      let javaSuperclass = javaClass.getSuperclass(),
      javaSuperclass.getName() != "java.lang.Object"
    {
      do {
        self.swiftSuperclass = try translator.getSwiftTypeName(javaSuperclass).swiftName
      } catch {
        translator.logUntranslated("Unable to translate '\(fullName)' superclass: \(error)")
        self.swiftSuperclass = nil
      }
    } else {
      self.swiftSuperclass = nil
    }

    // Interfaces.
    self.swiftInterfaces = javaClass.getGenericInterfaces().compactMap { (javaType) -> String? in
      guard let javaType else {
        return nil
      }

      do {
        let typeName = try translator.getSwiftTypeNameAsString(javaType, outerOptional: .nonoptional)
        return "\(typeName)"
      } catch {
        translator.logUntranslated("Unable to translate '\(fullName)' interface '\(javaType.getTypeName())': \(error)")
        return nil
      }
    }

    // Collect all of the class members that we will need to translate.
    // TODO: Switch over to "declared" versions of these whenever we don't need
    // to see inherited members.

    // Gather fields.
    for field in javaClass.getFields() {
      guard let field else { continue }
      addField(field)
    }

    // Gather constructors.
    for constructor in javaClass.getConstructors() {
      guard let constructor else { continue }
      addConstructor(constructor)
    }

    // Gather methods.
    for method in javaClass.getMethods() {
      guard let method else { continue }

      // Skip any methods that are expected to be implemented in Swift. We will
      // visit them in the second pass, over the *declared* methods, because
      // we want to see non-public methods as well.
      let implementedInSwift = method.isNative &&
        method.getDeclaringClass()!.equals(javaClass.as(JavaObject.self)!) &&
        translator.swiftNativeImplementations.contains(javaClass.getName())
      if implementedInSwift {
        continue
      }

      addMethod(method, isNative: false)
    }

    if translator.swiftNativeImplementations.contains(javaClass.getName()) {
      for method in javaClass.getDeclaredMethods() {
        guard let method else { continue }

        // Only visit native methods in this second pass.
        if !method.isNative {
          continue
        }

        addMethod(method, isNative: true)
      }
    }
  }
}

/// MARK: Collection of Java class members.
extension JavaClassTranslator {
  /// Add a field to the appropriate lists(s) for later translation.
  private mutating func addField(_ field: Field) {
    // Static fields go into a separate list.
    if field.isStatic {
      staticFields.append(field)

      // Enum constants will be used to produce a Swift enum projecting the
      // Java enum.
      if field.isEnumConstant() {
        enumConstants.append(field)
      }

      return
    }

    fields.append(field)
  }

  /// Add a constructor to the list of constructors for later translation.
  private mutating func addConstructor(_ constructor: Constructor<JavaObject>) {
    constructors.append(constructor)
  }

  /// Add a method to the appropriate list for later translation.
  private mutating func addMethod(_ method: Method, isNative: Bool) {
    switch (method.isStatic, isNative) {
    case (false, false): methods.add(method)
    case (true, false): staticMethods.add(method)
    case (false, true): nativeMethods.append(method)
    case (true, true): nativeStaticMethods.append(method)
    }
  }
}

/// MARK: Rendering of Java class members as Swift declarations.
extension JavaClassTranslator {
  /// Render the Swift declarations that will express this Java class in Swift.
  package func render() -> [DeclSyntax] {
    var allDecls: [DeclSyntax] = []
    allDecls.append(renderPrimaryType())
    allDecls.append(contentsOf: renderNestedClasses())
    if let staticMemberExtension = renderStaticMemberExtension() {
      allDecls.append(staticMemberExtension)
    }
    if let nativeMethodsProtocol = renderNativeMethodsProtocol() {
      allDecls.append(nativeMethodsProtocol)
    }
    return allDecls
  }

  /// Render the declaration for the main part of the Java class, which
  /// includes the constructors, non-static fields, and non-static methods.
  private func renderPrimaryType() -> DeclSyntax {
    // Render all of the instance fields as Swift properties.
    let properties = fields.compactMap { field in
      do {
        return try renderField(field)
      } catch {
        translator.logUntranslated("Unable to translate '\(javaClass.getName())' static field '\(field.getName())': \(error)")
        return nil
      }
    }

    // Declarations used to capture Java enums.
    let enumDecls: [DeclSyntax] = renderEnum(name: "\(swiftInnermostTypeName)Cases")

    // Render all of the constructors as Swift initializers.
    let initializers = constructors.compactMap { constructor in
      do {
        return try renderConstructor(constructor)
      } catch {
        translator.logUntranslated("Unable to translate '\(javaClass.getName())' constructor: \(error)")
        return nil
      }
    }

    // Render all of the instance methods in Swift.
    let instanceMethods = methods.methods.compactMap { method in
      do {
        return try renderMethod(method, implementedInSwift: false)
      } catch {
        translator.logUntranslated("Unable to translate '\(javaClass.getName())' method '\(method.getName())': \(error)")
        return nil
      }
    }

    // Collect all of the members of this type.
    let members = properties + enumDecls + initializers + instanceMethods

    // Compute the "extends" clause for the superclass.
    let extends = swiftSuperclass.map { ", extends: \($0).self" } ?? ""

    // Compute the string to capture all of the interfaces.
    let interfacesStr: String
    if swiftInterfaces.isEmpty {
      interfacesStr = ""
    } else {
      let prefix = javaClass.isInterface() ? "extends" : "implements"
      interfacesStr = ", \(prefix): \(swiftInterfaces.map { "\($0).self" }.joined(separator: ", "))"
    }

    // Emit the struct declaration describing the java class.
    let classOrInterface: String = isInterface ? "JavaInterface" : "JavaClass";
    var classDecl: DeclSyntax =
      """
      @\(raw: classOrInterface)(\(literal: javaClass.getName())\(raw: extends)\(raw: interfacesStr))
      public struct \(raw: swiftInnermostTypeName)\(raw: genericParameterClause) {
      \(raw: members.map { $0.description }.joined(separator: "\n\n"))
      }
      """

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
    return classDecl.formatted(using: translator.format).cast(DeclSyntax.self)
  }

  /// Render any nested classes that will not be rendered separately.
  func renderNestedClasses() -> [DeclSyntax] {
    return nestedClasses.compactMap { clazz in
      do {
        return try translator.translateClass(clazz)
      } catch {
        translator.logUntranslated("Unable to translate '\(javaClass.getName())' nested class '\(clazz.getName())': \(error)")
        return nil
      }
    }.flatMap(\.self)
  }

  /// Render the extension of JavaClass that collects all of the static
  /// fields and methods.
  package func renderStaticMemberExtension() -> DeclSyntax? {
    // Determine the where clause we need for static methods.
    let staticMemberWhereClause: String
    if !javaTypeParameters.isEmpty {
      let genericParameterNames = javaTypeParameters.compactMap { typeVar in
        typeVar.getName()
      }

      let genericArgumentClause = "<\(genericParameterNames.joined(separator: ", "))>"
      staticMemberWhereClause = " where ObjectType == \(swiftTypeName)\(genericArgumentClause)"
    } else {
      staticMemberWhereClause = ""
    }

    // Render static fields.
    let properties = staticFields.compactMap { field in
      // Translate each static field.
      do {
        return try renderField(field)
      } catch {
        translator.logUntranslated("Unable to translate '\(javaClass.getName())' field '\(field.getName())': \(error)")
        return nil
      }
    }

    // Render static methods.
    let methods = staticMethods.methods.compactMap { method in
      // Translate each static method.
      do {
        return try renderMethod(
          method, implementedInSwift: /*FIXME:*/false,
          genericParameterClause: genericParameterClause,
          whereClause: staticMemberWhereClause
        )
      } catch {
        translator.logUntranslated("Unable to translate '\(javaClass.getName())' static method '\(method.getName())': \(error)")
        return nil
      }
    }

    // Gather all of the members.
    let members = properties + methods
    if members.isEmpty {
      return nil
    }

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
      \(raw: members.map { $0.description }.joined(separator: "\n\n"))
      }
      """

    return extDecl.formatted(using: translator.format).cast(DeclSyntax.self)
  }

  /// Render the protocol used for native methods.
  func renderNativeMethodsProtocol() -> DeclSyntax? {
    guard translator.swiftNativeImplementations.contains(javaClass.getName()) else {
      return nil
    }

    let nativeMembers = nativeMethods.compactMap { method in
      do {
        return try renderMethod(
          method,
          implementedInSwift: true
        )
      } catch {
        translator.logUntranslated("Unable to translate '\(javaClass.getName())' method '\(method.getName())': \(error)")
        return nil
      }
    }

    if nativeMembers.isEmpty {
      return nil
    }

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

    return protocolDecl.formatted(using: translator.format).cast(DeclSyntax.self)
  }

  /// Render the given Java constructor as a Swift initializer.
  package func renderConstructor(
    _ javaConstructor: Constructor<some AnyJavaObject>
  ) throws -> DeclSyntax {
    let parameters = try translateParameters(javaConstructor.getParameters()) + ["environment: JNIEnvironment? = nil"]
    let parametersStr = parameters.map { $0.description }.joined(separator: ", ")
    let throwsStr = javaConstructor.throwsCheckedException ? "throws" : ""
    let accessModifier = javaConstructor.isPublic ? "public " : ""
    return """
      @JavaMethod
      \(raw: accessModifier)init(\(raw: parametersStr))\(raw: throwsStr)
      """
  }

  /// Translates the given Java method into a Swift declaration.
  package func renderMethod(
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
    let resultType = try translator.getSwiftTypeNameAsString(javaMethod.getGenericReturnType()!, outerOptional: .implicitlyUnwrappedOptional)
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

  /// Render a single Java field into the corresponding Swift property, or
  /// throw an error if that is not possible for any reason.
  package func renderField(_ javaField: Field) throws -> DeclSyntax {
    let typeName = try translator.getSwiftTypeNameAsString(javaField.getGenericType()!, outerOptional: .implicitlyUnwrappedOptional)
    let fieldAttribute: AttributeSyntax = javaField.isStatic ? "@JavaStaticField" : "@JavaField";
    let swiftFieldName = javaField.getName().escapedSwiftName
    return """
      \(fieldAttribute)(isFinal: \(raw: javaField.isFinal))
      public var \(raw: swiftFieldName): \(raw: typeName)
      """
  }

  package func renderEnum(name: String) -> [DeclSyntax] {
    if enumConstants.isEmpty {
      return []
    }

    let extensionSyntax: DeclSyntax = """
      public enum \(raw: name): Equatable {
        \(raw: enumConstants.map { "case \($0.getName())" }.joined(separator: "\n"))
      }
    """

    let mappingSyntax: DeclSyntax = """
      public var enumValue: \(raw: name)! {
        let classObj = self.javaClass
        \(raw: enumConstants.map {
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
      let classObj = try! JavaClass<Self>(environment: _environment)
      switch enumValue {
    \(raw: enumConstants.map {
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

      let typeName = try translator.getSwiftTypeNameAsString(javaParameter.getParameterizedType()!, outerOptional: .optional)
      let paramName = javaParameter.getName()
      return "_ \(raw: paramName): \(raw: typeName)"
    }
  }
}

/// Helper struct that collects methods, removing any that have been overridden
/// by a covariant method.
struct MethodCollector {
  var methods: [Method] = []

  /// Mapping from method names to the indices of each method within the
  /// list of methods.
  var methodsByName: [String: [Int]] = [:]

  /// Add this method to the collector.
  mutating func add(_ method: Method) {
    // Compare against existing methods with this same name.
    for existingMethodIndex in methodsByName[method.getName()] ?? [] {
      let existingMethod = methods[existingMethodIndex]
      switch MethodVariance(method, existingMethod) {
      case .equivalent, .unrelated:
        // Nothing to do.
        continue

      case .contravariantResult:
        // This method is worse than what we have; there is nothing to do.
        return

      case .covariantResult:
        // This method is better than the one we have; replace the one we
        // have with it.
        methods[existingMethodIndex] = method
        return
      }
    }

    // If we get here, there is no related method in the list. Add this
    // new method.
    methodsByName[method.getName(), default: []].append(methods.count)
    methods.append(method)
  }
}
