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
import SwiftSyntax
import OrderedCollections
import SwiftJavaConfigurationShared
import Logging

/// Utility type that translates a single Java class into its corresponding
/// Swift type and any additional helper types or functions.
struct JavaClassTranslator {
  /// The translator we are working with, which provides global knowledge
  /// needed for translation.
  let translator: JavaTranslator

  var log: Logger { 
    translator.log
  }

  /// The Java class (or interface) being translated.
  let javaClass: JavaClass<JavaObject>

  /// Whether to translate this Java class into a Swift class.
  ///
  /// This will be false for Java interfaces.
  let translateAsClass: Bool

  /// The type parameters to the Java class or interface.
  let javaTypeParameters: [TypeVariable<JavaClass<JavaObject>>]

  /// The set of nested classes of this class that will be rendered along
  /// with it.
  let nestedClasses: [JavaClass<JavaObject>]

  /// The full name of the Swift type that will be generated for this Java
  /// class.
  let swiftTypeName: String

  /// The effective Java superclass object, which is the nearest
  /// superclass that has been mapped into Swift.
  let effectiveJavaSuperclass: JavaClass<JavaObject>?

  /// The Swift name of the superclass.
  let swiftSuperclass: SwiftJavaParameterizedType?

  /// The Swift names of the interfaces that this class implements.
  let swiftInterfaces: [String]

  /// The annotations of the Java class
  let annotations: [Annotation]

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
  var genericParameters: [String] {
    if javaTypeParameters.isEmpty {
      return []
    }

    let genericParameters = javaTypeParameters.map { param in
      "\(param.getName()): AnyJavaObject"
    }

    return genericParameters
  }

  /// Prepare translation for the given Java class (or interface).
  init(javaClass: JavaClass<JavaObject>, translator: JavaTranslator) throws {
    let fullName = javaClass.getName()
    self.javaClass = javaClass
    self.translator = translator
    self.translateAsClass = translator.translateAsClass && !javaClass.isInterface()
    self.swiftTypeName = try translator.getSwiftTypeNameFromJavaClassName(
      fullName,
      preferValueTypes: false,
      escapeMemberNames: false
    )

    // Type parameters.
    self.javaTypeParameters = javaClass.getTypeParameters().compactMap { $0 }
    self.nestedClasses = translator.nestedClasses[fullName] ?? []

    // Superclass, incl parameter types (if any)
    if !javaClass.isInterface() {
      var javaSuperclass = javaClass.getSuperclass()
      var javaGenericSuperclass: JavaReflectType? = javaClass.getGenericSuperclass()
      var swiftSuperclassName: String? = nil
      var swiftSuperclassTypeArgs: [String] = []
      while let javaSuperclassNonOpt = javaSuperclass {
        do {
          swiftSuperclassName = try translator.getSwiftTypeName(javaSuperclassNonOpt, preferValueTypes: false).swiftName
          if let javaGenericSuperclass = javaGenericSuperclass?.as(JavaReflectParameterizedType.self) {
            for typeArg in javaGenericSuperclass.getActualTypeArguments() {
              let javaTypeArgName = typeArg?.getTypeName() ?? ""
              if let swiftTypeArgName = self.translator.translatedClasses[javaTypeArgName] {
                swiftSuperclassTypeArgs.append(swiftTypeArgName.qualifiedName)
              } else {
                swiftSuperclassTypeArgs.append("/* MISSING MAPPING FOR */ \(javaTypeArgName)")
              }
            }
          }
          break
        } catch {
          translator.logUntranslated("Unable to translate '\(fullName)' superclass: \(error)")
        }

        javaSuperclass = javaSuperclassNonOpt.getSuperclass()
        javaGenericSuperclass = javaClass.getGenericSuperclass()
      }

      self.effectiveJavaSuperclass = javaSuperclass
      self.swiftSuperclass = SwiftJavaParameterizedType(
        name: swiftSuperclassName, 
        typeArguments: swiftSuperclassTypeArgs)
    } else {
      self.effectiveJavaSuperclass = nil
      self.swiftSuperclass = nil
    }

    // Interfaces.
    self.swiftInterfaces = javaClass.getGenericInterfaces().compactMap { (javaType) -> String? in
      guard let javaType else {
        return nil
      }

      do {
        let typeName = try translator.getSwiftTypeNameAsString(
          javaType,
          preferValueTypes: false,
          outerOptional: .nonoptional
        )
        return "\(typeName)"
      } catch {
        translator.logUntranslated("Unable to translate '\(fullName)' interface '\(javaType.getTypeName())': \(error)")
        return nil
      }
    }

    self.annotations = javaClass.getAnnotations().compactMap(\.self)

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
    let methods = translateAsClass
      ? javaClass.getDeclaredMethods()
      : javaClass.getMethods()
    for method in methods {
      guard let method else { continue }

      guard shouldExtract(method: method) else {
        continue
      }

      // Skip any methods that are expected to be implemented in Swift. We will
      // visit them in the second pass, over the *declared* methods, because
      // we want to see non-public methods as well.
      let implementedInSwift = method.isNative &&
        method.getDeclaringClass()!.equals(javaClass.as(JavaObject.self)!) &&
        translator.swiftNativeImplementations.contains(javaClass.getName())
      if implementedInSwift {
        continue
      }

      guard method.getName().isValidSwiftFunctionName else {
        log.warning("Skipping method \(method.getName()) because it is not a valid Swift function name")
        continue
      }

      addMethod(method, isNative: false)
    }

    if translator.swiftNativeImplementations.contains(javaClass.getName()) {
      // Gather the native methods we're going to implement.
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

  /// Determines whether a method should be extracted for translation.
  /// Only look at public and protected methods here.
  private func shouldExtract(method: Method) -> Bool {
    switch self.translator.config.effectiveMinimumInputAccessLevelMode {
      case .internal:
        return method.isPublic || method.isProtected || method.isPackage
      case .package:
        return method.isPublic || method.isProtected || method.isPackage
      case .public:
        return method.isPublic || method.isProtected
    }
  }

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

    // Don't include inherited fields when translating to a class.
    if translateAsClass &&
        !field.getDeclaringClass()!.equals(javaClass.as(JavaObject.self)!) {
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
    allDecls.append(contentsOf: renderAnnotationExtensions())
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

    // Compute the "extends" clause for the superclass (of the struct
    // formulation) or the inheritance clause (for the class
    // formulation).
    let extendsClause: String
    let inheritanceClause: String
    if translateAsClass {
      extendsClause = ""
      inheritanceClause = 
        if let swiftSuperclass, swiftSuperclass.typeArguments.isEmpty {
           ": \(swiftSuperclass.name)" 
        } else if let swiftSuperclass {
           ": \(swiftSuperclass.name)<\(swiftSuperclass.typeArguments.joined(separator: ", "))>" 
        } else { 
          "" 
        }
    } else {
      extendsClause = 
        if let swiftSuperclass {
          ", extends: \(swiftSuperclass.render()).self" 
        } else {
          ""
        }
      inheritanceClause = ""
    }

    // Compute the string to capture all of the interfaces.
    let interfacesStr: String
    if swiftInterfaces.isEmpty {
      interfacesStr = ""
    } else {
      let prefix = javaClass.isInterface() ? "extends" : "implements"
      interfacesStr = ", \(prefix): \(swiftInterfaces.map { "\($0).self" }.joined(separator: ", "))"
    }

    let genericParameterClause = 
      if genericParameters.isEmpty { 
        ""
      } else {
        "<\(genericParameters.joined(separator: ", "))>"
      }

    // Emit the struct declaration describing the java class.
    let classOrInterface: String = isInterface ? "JavaInterface" : "JavaClass";
    let introducer = translateAsClass ? "open class" : "public struct"
    var classDecl: DeclSyntax =
      """
      @\(raw: classOrInterface)(\(literal: javaClass.getName())\(raw: extendsClause)\(raw: interfacesStr))
      \(raw: introducer) \(raw: swiftInnermostTypeName)\(raw: genericParameterClause)\(raw: inheritanceClause) {
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
    return nestedClasses
      .sorted {
        $0.getName() < $1.getName()
      }.compactMap { clazz in
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
      staticMemberWhereClause = " where ObjectType == \(swiftTypeName)\(genericArgumentClause)" // FIXME: move the 'where ...' part into the render bit
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
          genericParameters: genericParameters,
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
    if genericParameters.isEmpty {
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

  func renderAnnotationExtensions() -> [DeclSyntax] {
    var extensions: [DeclSyntax] = []

    for annotation in annotations {
      let annotationName = annotation.annotationType().getName().splitSwiftTypeName().name
      if annotationName == "ThreadSafe" || annotationName == "Immutable" { // If we are threadsafe, mark as unchecked Sendable
        extensions.append(
          """
          extension \(raw: swiftTypeName): @unchecked Swift.Sendable { }
          """
        )
      } else if annotationName == "NotThreadSafe" { // If we are _not_ threadsafe, mark sendable unavailable
        extensions.append(
          """
          @available(unavailable, *)
          extension \(raw: swiftTypeName): Swift.Sendable { }
          """
        )
      }
    }

    return extensions
  }

  /// Render the given Java constructor as a Swift initializer.
  package func renderConstructor(
    _ javaConstructor: Constructor<some AnyJavaObject>
  ) throws -> DeclSyntax {
    let parameters = try translateJavaParameters(javaConstructor.getParameters()) + ["environment: JNIEnvironment? = nil"]
    let parametersStr = parameters.map { $0.description }.joined(separator: ", ")
    let throwsStr = javaConstructor.throwsCheckedException ? "throws" : ""
    let accessModifier = javaConstructor.isPublic ? "public " : ""
    let convenienceModifier = translateAsClass ? "convenience " : ""
    let nonoverrideAttribute = translateAsClass ? "@_nonoverride " : ""
    
    // FIXME: handle generics in constructors
    return """
      @JavaMethod
      \(raw: nonoverrideAttribute)\(raw: accessModifier)\(raw: convenienceModifier)init(\(raw: parametersStr))\(raw: throwsStr)
      """
  }

  func genericParameterIsUsedInSignature(_ typeParam: TypeVariable<Method>, in method: Method) -> Bool {
    // --- Return type
    // Is the return type exactly the type param
    // FIXME: make this equals based?
    if method.getGenericReturnType().getTypeName() == typeParam.getTypeName() {
      return true
    }

    if let parameterizedReturnType = method.getGenericReturnType().as(ParameterizedType.self) {
      for actualTypeParam in parameterizedReturnType.getActualTypeArguments() {
        guard let actualTypeParam else { continue }
        if actualTypeParam.isEqualTo(typeParam.as(Type.self)) {
          return true
        }
      }
    }

    // --- Parameter types
    for parameter in method.getParameters() {
      if let parameterizedType = parameter?.getParameterizedType() {
        if parameterizedType.isEqualTo(typeParam.as(Type.self)) {
          return true
        }
      }
    }

    return false
  }

  // TODO: make it more precise with the "origin" of the generic parameter (outer class etc)
  func collectMethodGenericParameters(
    genericParameters: [String],
    method: Method
  ) -> OrderedSet<String> {
    var allGenericParameters = OrderedSet(genericParameters)
    
    let typeParameters = method.getTypeParameters()
    for typeParameter in typeParameters {
      guard let typeParameter else { continue }
      
      guard genericParameterIsUsedInSignature(typeParameter, in: method) else {
        continue
      }

      allGenericParameters.append("\(typeParameter.getTypeName()): AnyJavaObject")
    }

    return allGenericParameters
  }

  /// Translates the given Java method into a Swift declaration.
  package func renderMethod(
    _ javaMethod: Method,
    implementedInSwift: Bool,
    genericParameters: [String] = [],
    whereClause: String = ""
  ) throws -> DeclSyntax {
    // Map the generic params on the method.
    let allGenericParameters = collectMethodGenericParameters(genericParameters: genericParameters, method: javaMethod)
    let genericParameterClauseStr = 
      if allGenericParameters.isEmpty {
        ""
      } else {
        "<\(allGenericParameters.joined(separator: ", "))>"
      }

    // Map the parameters.
    let parameters = try translateJavaParameters(javaMethod)
    let parametersStr = parameters.map { $0.description }.joined(separator: ", ")

    // Map the result type.
    let resultTypeStr: String
    let resultType = try translator.getSwiftReturnTypeNameAsString(
      method: javaMethod, 
      preferValueTypes: true, 
      outerOptional: .implicitlyUnwrappedOptional
    )
    let hasTypeEraseGenericResultType: Bool = 
      isTypeErased(javaMethod.getGenericReturnType())

    // FIXME: cleanup the checking here
    if resultType != "Void" && resultType != "Swift.Void" {
      resultTypeStr = " -> \(resultType)"
    } else {
      resultTypeStr = ""
    }

    // --- Handle other effects
    let throwsStr = javaMethod.throwsCheckedException ? "throws" : ""
    let swiftMethodName = javaMethod.getName().escapedSwiftName
    let swiftOptionalMethodName = "\(javaMethod.getName())Optional".escapedSwiftName

    // Compute the parameters for '@...JavaMethod(...)'
    let methodAttribute: AttributeSyntax
      if implementedInSwift {
        methodAttribute = ""
      } else {
        var methodAttributeStr =
          if javaMethod.isStatic {
            "@JavaStaticMethod"
          } else {
            "@JavaMethod"
          }
        // Do we need to record any generic information, in order to enable type-erasure for the upcalls?
        var parameters: [String] = []
        if hasTypeEraseGenericResultType {
          parameters.append("typeErasedResult: \"\(resultType)\"")
        }
        // TODO: generic parameters?
        
        if !parameters.isEmpty {
          methodAttributeStr += "("
          methodAttributeStr.append(parameters.joined(separator: ", "))
          methodAttributeStr += ")"
        }
        methodAttributeStr += "\n"
        methodAttribute = "\(raw: methodAttributeStr)"
      }

    let accessModifier = implementedInSwift ? ""
      : (javaMethod.isStatic || !translateAsClass) ? "public "
      : "open "
    let overrideOpt = (translateAsClass && !javaMethod.isStatic && isOverride(javaMethod))
      ? "override "
      : ""

    // FIXME: refactor this so we don't have to duplicate the method signatures
    if resultType.optionalWrappedType() != nil || parameters.contains(where: { $0.type.trimmedDescription.optionalWrappedType() != nil }) {
      let parameters = parameters.map { param -> (clause: FunctionParameterSyntax, passedArg: String) in
        let name = param.secondName!.trimmedDescription

        return if let optionalType = param.type.trimmedDescription.optionalWrappedType() {
          (clause: "_ \(raw: name): \(raw: optionalType)", passedArg: "\(name).toJavaOptional()")
        } else {
          (clause: param, passedArg: "\(name)")
        }
      }

      let resultOptional: String = resultType.optionalWrappedType() ?? resultType
      let baseBody: ExprSyntax = "\(raw: javaMethod.throwsCheckedException ? "try " : "")\(raw: swiftMethodName)(\(raw: parameters.map(\.passedArg).joined(separator: ", ")))"
      let body: ExprSyntax = 
        if resultType.optionalWrappedType() != nil {
          "Optional(javaOptional: \(baseBody))"
        } else {
          baseBody
        }


      return 
        """
        \(methodAttribute)\(raw: accessModifier)\(raw: overrideOpt)func \(raw: swiftMethodName)\(raw: genericParameterClauseStr)(\(raw: parametersStr))\(raw: throwsStr)\(raw: resultTypeStr)\(raw: whereClause)
        
        \(raw: accessModifier)\(raw: overrideOpt)func \(raw: swiftOptionalMethodName)\(raw: genericParameterClauseStr)(\(raw: parameters.map(\.clause.description).joined(separator: ", ")))\(raw: throwsStr) -> \(raw: resultOptional)\(raw: whereClause) {
          \(body)
        }
        """
    } else {
      return 
        """
        \(methodAttribute)\(raw: accessModifier)\(raw: overrideOpt)func \(raw: swiftMethodName)\(raw: genericParameterClauseStr)(\(raw: parametersStr))\(raw: throwsStr)\(raw: resultTypeStr)\(raw: whereClause)
        """
    }
  }

  /// Render a single Java field into the corresponding Swift property, or
  /// throw an error if that is not possible for any reason.
  package func renderField(_ javaField: Field) throws -> DeclSyntax {
    let typeName = try translator.getSwiftTypeNameAsString(
      javaField.getGenericType()!,
      preferValueTypes: true,
      outerOptional: .implicitlyUnwrappedOptional
    )
    let fieldAttribute: AttributeSyntax = javaField.isStatic ? "@JavaStaticField" : "@JavaField";
    let swiftFieldName = javaField.getName().escapedSwiftName

    if let optionalType = typeName.optionalWrappedType() {
      let setter = if !javaField.isFinal {
      """
      
        set {
          \(swiftFieldName) = newValue.toJavaOptional()
        }
      """
      } else {
        ""
      }
      return """
      \(fieldAttribute)(isFinal: \(raw: javaField.isFinal))
      public var \(raw: swiftFieldName): \(raw: typeName)

      
      public var \(raw: swiftFieldName)Optional: \(raw: optionalType) {
        get {
          Optional(javaOptional: \(raw: swiftFieldName))
        }\(raw: setter)
      }
      """
    } else {
      return """
      \(fieldAttribute)(isFinal: \(raw: javaField.isFinal))
      public var \(raw: swiftFieldName): \(raw: typeName)
      """
    }
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

    let convenienceModifier = translateAsClass ? "convenience " : ""
    let initSyntax: DeclSyntax = """
    public \(raw: convenienceModifier)init(_ enumValue: \(raw: name), environment: JNIEnvironment? = nil) {
      let _environment = if let environment {
        environment
      } else {
        try! JavaVirtualMachine.shared().environment()
      }
      let classObj = try! JavaClass<\(raw: swiftInnermostTypeName)>(environment: _environment)
      switch enumValue {
    \(raw: enumConstants.map {
      return """
          case .\($0.getName()):
            if let \($0.getName()) = classObj.\($0.getName()) {
              \(translateAsClass
                  ? "self.init(javaHolder: \($0.getName()).javaHolder)"
                  : "self = \($0.getName())")
            } else {
              fatalError("Enum value \($0.getName()) was unexpectedly nil, please re-run swift-java on the most updated Java class") 
            }
      """
    }.joined(separator: "\n"))
      }
    }
    """

    return [extensionSyntax, mappingSyntax, initSyntax]
  }

  // Translate a Java parameter list into Swift parameters.
  private func translateJavaParameters(
    _ javaMethod: JavaLangReflect.Method
  ) throws -> [FunctionParameterSyntax] {
    let parameters: [Parameter?] = javaMethod.getParameters()

    return try parameters.compactMap { javaParameter in
      guard let javaParameter else { return nil }

      let typeName = try translator.getSwiftTypeNameAsString(
        method: javaMethod,
        javaParameter.getParameterizedType()!,
        preferValueTypes: true,
        outerOptional: .optional
      )
      let paramName = javaParameter.getName()
      return "_ \(raw: paramName): \(raw: typeName)"
    }
  }

  // Translate a Java parameter list into Swift parameters.
  @available(*, deprecated, message: "Prefer the method based version") // FIXME: constructors are not well handled
  private func translateJavaParameters(
    _ parameters: [Parameter?]
  ) throws -> [FunctionParameterSyntax] {
    return try parameters.compactMap { javaParameter in
      guard let javaParameter else { return nil }

      let typeName = try translator.getSwiftTypeNameAsString(
        javaParameter.getParameterizedType()!,
        preferValueTypes: true,
        outerOptional: .optional
      )
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

// MARK: Utility functions

extension JavaClassTranslator {
  /// Determine whether this method is an override of another Java
  /// method.
  func isOverride(_ method: Method) -> Bool {
    var currentSuperclass = effectiveJavaSuperclass
    while let currentSuperclassNonOpt = currentSuperclass {
      // Set the loop up for the next run.
      defer {
        currentSuperclass = currentSuperclassNonOpt.getSuperclass()
      }

      do {
        // If this class didn't get translated into Swift, skip it.
        if translator.translatedClasses[currentSuperclassNonOpt.getName()] == nil {
          continue
        }

        // If this superclass declares a method with the same parameter types,
        // we have an override.
        guard let overriddenMethod = try currentSuperclassNonOpt
          .getDeclaredMethod(method.getName(), method.getParameterTypes()) else {
          continue
        }

        guard shouldExtract(method: overriddenMethod) else {
          continue
        }

        // We know that Java considers this method an override. However, it is
        // possible that Swift will not consider it an override, because Java
        // has subtyping relations that Swift does not.
        if method.getGenericReturnType().isEqualToOrSubtypeOf(overriddenMethod.getGenericReturnType()) {
          return true
        }
      } catch {
        log.debug("Failed to determine if method '\(method)' is an override, error: \(error)")
      }
    }

    return false
  }
}

extension [Type?] {
  /// Determine whether the types in the array match the other array.
  func allTypesEqual(_ other: [Type?]) -> Bool {
    if self.count != other.count {
      return false
    }

    for (selfType, otherType) in zip(self, other) {
      if !selfType!.isEqualTo(otherType!) {
        return false
      }
    }

    return true
  }
}

