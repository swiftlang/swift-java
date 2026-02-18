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
import Logging
import SwiftJava
import SwiftJavaConfigurationShared
import SwiftSyntax

extension Type {
  /// Adjust the given type to use its bounds, mirroring what we do in
  /// mapping Java types into Swift.
  func adjustToJavaBounds(adjusted: inout Bool) -> Type {
    if let typeVariable = self.as(TypeVariable<GenericDeclaration>.self),
      typeVariable.getBounds().count == 1,
      let bound = typeVariable.getBounds()[0]
    {
      adjusted = true
      return bound
    }

    if let wildcardType = self.as(WildcardType.self),
      wildcardType.getUpperBounds().count == 1,
      let bound = wildcardType.getUpperBounds()[0]
    {
      adjusted = true
      return bound
    }

    return self
  }

  /// Determine whether this type is equivalent to or a subtype of the other
  /// type.
  func isEqualTo(_ other: Type, file: String = #file, line: Int = #line, function: String = #function) -> Bool {
    if self.javaHolder.object == other.javaHolder.object {
      return true
    }

    // First, adjust types to their bounds, if we need to.
    var anyAdjusted: Bool = false
    let adjustedSelf = self.adjustToJavaBounds(adjusted: &anyAdjusted)
    let adjustedOther = other.adjustToJavaBounds(adjusted: &anyAdjusted)
    if anyAdjusted {
      return adjustedSelf.isEqualTo(adjustedOther)
    }

    // If both are classes, check for equivalence.
    if let selfClass = self.as(JavaClass<JavaObject>.self),
      let otherClass = other.as(JavaClass<JavaObject>.self)
    {
      return selfClass.equals(otherClass.as(JavaObject.self))
    }

    // If both are arrays, check that their component types are equivalent.
    if let selfArray = self.as(GenericArrayType.self),
      let otherArray = other.as(GenericArrayType.self)
    {
      return selfArray.getGenericComponentType().isEqualTo(otherArray.getGenericComponentType())
    }

    // If both are parameterized types, check their raw type and type
    // arguments for equivalence.
    if let selfParameterizedType = self.as(ParameterizedType.self),
      let otherParameterizedType = other.as(ParameterizedType.self)
    {
      if !selfParameterizedType.getRawType().isEqualTo(otherParameterizedType.getRawType()) {
        return false
      }

      return selfParameterizedType.getActualTypeArguments()
        .allTypesEqual(otherParameterizedType.getActualTypeArguments())
    }

    // If both are type variables, compare their bounds.
    // FIXME: This is a hack.
    if let selfTypeVariable = self.as(TypeVariable<GenericDeclaration>.self),
      let otherTypeVariable = other.as(TypeVariable<GenericDeclaration>.self)
    {
      return selfTypeVariable.getBounds().allTypesEqual(otherTypeVariable.getBounds())
    }

    // If both are wildcards, compare their upper and lower bounds.
    if let selfWildcard = self.as(WildcardType.self),
      let otherWildcard = other.as(WildcardType.self)
    {
      return selfWildcard.getUpperBounds().allTypesEqual(otherWildcard.getUpperBounds())
        && selfWildcard.getLowerBounds().allTypesEqual(otherWildcard.getLowerBounds())
    }

    return false
  }

  /// Determine whether this type is equivalent to or a subtype of the
  /// other type.
  func isEqualToOrSubtypeOf(_ other: Type) -> Bool {
    // First, adjust types to their bounds, if we need to.
    var anyAdjusted: Bool = false
    let adjustedSelf = self.adjustToJavaBounds(adjusted: &anyAdjusted)
    let adjustedOther = other.adjustToJavaBounds(adjusted: &anyAdjusted)
    if anyAdjusted {
      return adjustedSelf.isEqualToOrSubtypeOf(adjustedOther)
    }

    if isEqualTo(other) {
      return true
    }

    // If both are classes, check for subclassing.
    if let selfClass = self.as(JavaClass<JavaObject>.self),
      let otherClass = other.as(JavaClass<JavaObject>.self)
    {
      // If either is a Java array, then this cannot be a subtype relationship
      // in Swift.
      if selfClass.isArray() || otherClass.isArray() {
        return false
      }

      return selfClass.isSubclass(of: otherClass)
    }

    // Anything object-like is a subclass of java.lang.Object
    if let otherClass = other.as(JavaClass<JavaObject>.self),
      otherClass.getName() == "java.lang.Object"
    {
      if self.is(GenericArrayType.self) || self.is(ParameterizedType.self) || self.is(WildcardType.self)
        || self.is(TypeVariable<GenericDeclaration>.self)
      {
        return true
      }
    }
    return false
  }
}
