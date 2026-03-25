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

import JavaLangReflect
import SwiftBasicFormat
import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaJNICore
import SwiftSyntax
import SwiftSyntaxBuilder

struct GenericJavaTypeOriginInfo {
  enum GenericSource {
    /// The source of the generic
    case `class`([Type])
    case method
  }

  var source: GenericSource
  var type: Type
}

/// if the type (that is used by the Method) is generic, return if the use originates from the method, or a surrounding class.
func getGenericJavaTypeOriginInfo(_ type: Type?, from method: Method) -> [GenericJavaTypeOriginInfo] {
  guard let type else {
    return []
  }

  guard isGenericJavaType(type) else {
    return [] // it's not a generic type, no "origin" of the use to detect
  }

//  var methodTypeVars = method.getTypeParameters() as [TypeVariable<JavaLangReflect.Method>?]

  // TODO: also handle nested classes here...
//  var classTypeVars = method.getDeclaringClass().getTypeParameters()

//  var usedTypeVars: [TypeVariable<JavaObject>] = []

  return []
}

func isGenericJavaType(_ type: Type?) -> Bool {
  guard let type else {
    return false
  }

  // Check if it's a type variable (e.g., T, E, etc.)
  if type.as(TypeVariable<JavaObject>.self) != nil {
    return true
  }

  // Check if it's a parameterized type (e.g., List<T>, Map<K,V>)
  if let paramType = type.as(ParameterizedType.self) {
    let typeArgs: [Type?] = paramType.getActualTypeArguments()

    // Check if any of the type arguments are generic
    for typeArg in typeArgs {
      guard let typeArg else { continue }
      if isGenericJavaType(typeArg) {
        return true
      }
    }
  }

  // Check if it's a generic array type (e.g., T[], List<T>[])
  if let arrayType = type.as(GenericArrayType.self) {
    let componentType = arrayType.getGenericComponentType()
    return isGenericJavaType(componentType)
  }

  // Check if it's a wildcard type (e.g., ? extends Number, ? super String)
  if type.as(WildcardType.self) != nil {
    return true
  }

  return false
}

/// Check if a type is type-erased att runtime.
///
/// E.g. in a method returning a generic `T` the T is type erased and must
/// be represented as a `java.lang.Object` instead.
func isTypeErased(_ type: Type?) -> Bool {
  guard let type else {
    return false
  }

  // Check if it's a type variable (e.g., T, E, etc.)
  if type.as(TypeVariable<JavaObject>.self) != nil {
    return true
  }

  // Check if it's a wildcard type (e.g., ? extends Number, ? super String)
  if type.as(WildcardType.self) != nil {
    return true
  }

  return false
}

/// Handles generic type substitution by mapping type variables of ancestor classes
/// to actual types provided in 'extends' or 'implements' clauses.
struct SubstitutionMap {
  private struct MapKey: Hashable {
    var declaringClassName: String
    var typeVariableName: String
  }
  private var mapping: [MapKey: Type] = [:]

  init(startingFrom javaClass: JavaClass<JavaObject>) {
    buildSubstitutionMap(for: javaClass)
  }

  private mutating func buildSubstitutionMap(for currentClass: JavaClass<JavaObject>) {
    var genericParents: [Type] = currentClass.getGenericInterfaces().compactMap { $0 }
    if let genericSuperclass = currentClass.getGenericSuperclass() {
      genericParents.append(genericSuperclass)
    }

    for genericParent in genericParents {
      guard let parameterizedParent = genericParent.as(ParameterizedType.self) else {
        // If the parent is not parameterized, still check its ancestors recursively
        if let rawParent = genericParent.as(JavaClass<JavaObject>.self) {
          buildSubstitutionMap(for: rawParent)
        }
        continue
      }
      guard let rawParent = parameterizedParent.getRawType()?.as(JavaClass<JavaObject>.self) else {
        continue
      }

      let typeParameters = rawParent.getTypeParameters()
      let actualTypeArguments = parameterizedParent.getActualTypeArguments()

      for (typeParam, actualArg) in zip(typeParameters, actualTypeArguments) {
        guard let typeParam, let actualArg else { continue }

        let key = MapKey(
          declaringClassName: rawParent.getName(),
          typeVariableName: typeParam.getName()
        )
        mapping[key] = actualArg
      }

      buildSubstitutionMap(for: rawParent)
    }
  }

  func resolve(_ type: Type) -> Type? {
    if let typeVar = type.as(TypeVariable<GenericDeclaration>.self),
      let declClass = typeVar.getGenericDeclaration().as(JavaClass<JavaObject>.self)
    {
      let key = MapKey(
        declaringClassName: declClass.getName(),
        typeVariableName: typeVar.getName()
      )
      if let substituted = mapping[key] {
        // Recursively resolve if the substituted type is also a type variable.
        return resolve(substituted) ?? substituted
      }
    }
    return nil
  }
}
