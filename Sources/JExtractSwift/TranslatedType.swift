//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaTypes
import SwiftSyntax

extension Swift2JavaVisitor {
  /// Produce the C-compatible type for the given type, or throw an error if
  /// there is no such type.
  func cCompatibleType(for type: TypeSyntax) throws -> TranslatedType {
    switch type.as(TypeSyntaxEnum.self) {
    case .arrayType, .attributedType, .classRestrictionType, .compositionType,
        .dictionaryType, .implicitlyUnwrappedOptionalType, .metatypeType,
        .missingType, .namedOpaqueReturnType,
        .optionalType, .packElementType, .packExpansionType, .someOrAnyType,
        .suppressedType, .tupleType:
      throw TypeTranslationError.unimplementedType(type)

    case .functionType(let functionType):
      // FIXME: Temporary hack to keep existing code paths working.
      if functionType.trimmedDescription == "() -> ()" {
        return TranslatedType(
          cCompatibleConvention: .direct,
          originalSwiftType: type,
          cCompatibleSwiftType: "@convention(c) () -> Void",
          cCompatibleJavaMemoryLayout: .cFunction,
          javaType: .javaLangRunnable
        )
      }

      throw TypeTranslationError.unimplementedType(type)

    case .memberType(let memberType):
      // If the parent type isn't a known module, translate it.
      // FIXME: Need a more reasonable notion of which names are module names
      // for this to work.
      let parentType: TranslatedType?
      if memberType.baseType.trimmedDescription == "Swift" {
        parentType = nil
      } else {
        parentType = try cCompatibleType(for: memberType.baseType)
      }

      // Translate the generic arguments to the C-compatible types.
      let genericArgs = try memberType.genericArgumentClause.map { genericArgumentClause in
        try genericArgumentClause.arguments.map { argument in
          try cCompatibleType(for: argument.argument)
        }
      }

      // Resolve the C-compatible type by name.
      return try translateType(
        for: type,
        parent: parentType,
        name: memberType.name.text,
        genericArguments: genericArgs
      )

    case .identifierType(let identifierType):
      // Translate the generic arguments to the C-compatible types.
      let genericArgs = try identifierType.genericArgumentClause.map { genericArgumentClause in
        try genericArgumentClause.arguments.map { argument in
          try cCompatibleType(for: argument.argument)
        }
      }

      // Resolve the C-compatible type by name.
      return try translateType(
        for: type,
        parent: nil,
        name: identifierType.name.text,
        genericArguments: genericArgs
      )
    }
  }

  /// Produce the C compatible type by performing name lookup on the Swift type.
  func translateType(
    for type: TypeSyntax,
    parent: TranslatedType?,
    name: String,
    genericArguments: [TranslatedType]?
  ) throws -> TranslatedType {
    // Look for a primitive type with this name.
    if parent == nil, let primitiveType = JavaType(swiftTypeName: name) {
      return TranslatedType(
        cCompatibleConvention: .direct,
        originalSwiftType: "\(raw: name)",
        cCompatibleSwiftType: "Swift.\(raw: name)",
        cCompatibleJavaMemoryLayout: .primitive(primitiveType),
        javaType: primitiveType
      )
    }

    // If this is the Swift "Int" type, it's primitive in Java but might
    // map to either "int" or "long" depending whether the platform is
    // 32-bit or 64-bit.
    if parent == nil, name == "Int" {
      return TranslatedType(
        cCompatibleConvention: .direct,
        originalSwiftType: "\(raw: name)",
        cCompatibleSwiftType: "Swift.\(raw: name)",
        cCompatibleJavaMemoryLayout: .int,
        javaType: translator.javaPrimitiveForSwiftInt
      )
    }

    // Identify the various pointer types from the standard library.
    if let (requiresArgument, _, _) = name.isNameOfSwiftPointerType {
      // Dig out the pointee type if needed.
      if requiresArgument {
        guard let genericArguments else {
          throw TypeTranslationError.missingGenericArguments(type)
        }

        guard genericArguments.count == 1 else {
          throw TypeTranslationError.missingGenericArguments(type)
        }
      } else if let genericArguments {
        throw TypeTranslationError.unexpectedGenericArguments(type, genericArguments)
      }

      return TranslatedType(
        cCompatibleConvention: .direct,
        originalSwiftType: type,
        cCompatibleSwiftType: "UnsafeMutableRawPointer",
        cCompatibleJavaMemoryLayout: .heapObject,
        javaType: .javaForeignMemorySegment
      )
    }

    // Generic types aren't mapped into Java.
    if let genericArguments {
      throw TypeTranslationError.unexpectedGenericArguments(type, genericArguments)
    }

    // Nested types aren't mapped into Java.
    if parent != nil {
      throw TypeTranslationError.nestedType(type)
    }

    // Swift types are passed indirectly.
    // FIXME: Look up type names to figure out which ones are exposed and how.
    return TranslatedType(
      cCompatibleConvention: .indirect,
      originalSwiftType: type,
      cCompatibleSwiftType: "UnsafeMutablePointer<\(type)>",
      cCompatibleJavaMemoryLayout: .heapObject,
      javaType: .class(package: nil, name: name)
    )
  }
}

extension String {
  /// Determine whether this string names one of the Swift pointer types.
  ///
  /// - Returns: a tuple describing three pieces of information:
  ///     1. Whether the pointer type requires a generic argument for the
  ///        pointee.
  ///     2. Whether the memory referenced by the pointer is mutable.
  ///     3. Whether the pointer type has a `count` property describing how
  ///        many elements it points to.
  fileprivate var isNameOfSwiftPointerType: (requiresArgument: Bool, mutable: Bool, hasCount: Bool)? {
    switch self {
    case "COpaquePointer", "UnsafeRawPointer":
      return (requiresArgument: false, mutable: true, hasCount: false)

    case "UnsafeMutableRawPointer":
      return (requiresArgument: false, mutable: true, hasCount: false)

    case "UnsafePointer":
      return (requiresArgument: true, mutable: false, hasCount: false)

    case "UnsafeMutablePointer":
      return (requiresArgument: true, mutable: true, hasCount: false)

    case "UnsafeBufferPointer":
      return (requiresArgument: true, mutable: false, hasCount: true)

    case "UnsafeMutableBufferPointer":
      return (requiresArgument: true, mutable: false, hasCount: true)

    case "UnsafeRawBufferPointer":
      return (requiresArgument: false, mutable: false, hasCount: true)

    case "UnsafeMutableRawBufferPointer":
      return (requiresArgument: false, mutable: true, hasCount: true)

    default:
      return nil
    }
  }
}

enum ParameterConvention {
  case direct
  case indirect
}

struct TranslatedType {
  /// How a parameter of this type will be passed through C functions.
  var cCompatibleConvention: ParameterConvention

  /// The original Swift type, as written in the source.
  var originalSwiftType: TypeSyntax

  /// The C-compatible Swift type that should be used in any C -> Swift thunks
  /// emitted in Swift.
  var cCompatibleSwiftType: TypeSyntax

  /// The Java MemoryLayout constant that is used to describe the layout of
  /// the type in memory.
  var cCompatibleJavaMemoryLayout: CCompatibleJavaMemoryLayout

  /// The Java type that is used to present these values in Java.
  var javaType: JavaType
}

extension TranslatedType {
  var importedTypeName: ImportedTypeName {
    ImportedTypeName(
      swiftTypeName: originalSwiftType.trimmedDescription,
      javaType: javaType
    )
  }
}

/// Describes the C-compatible layout as it should be referenced from Java.
enum CCompatibleJavaMemoryLayout {
  /// A primitive Java type that has a direct counterpart in C.
  case primitive(JavaType)

  /// The Swift "Int" type, which may be either a Java int (32-bit platforms) or
  /// Java long (64-bit platforms).
  case int

  /// A Swift heap object, which is treated as a pointer for interoperability
  /// purposes but must be retained/released to keep it alive.
  case heapObject

  /// A C function pointer. In Swift, this will be a @convention(c) function.
  /// In Java, a downcall handle to a function.
  case cFunction
}

extension TranslatedType {
  /// Determine the foreign value layout to use for the translated type with
  /// the Java Foreign Function and Memory API.
  var foreignValueLayout: ForeignValueLayout {
    switch cCompatibleJavaMemoryLayout {
    case .primitive(let javaType):
      switch javaType {
      case .boolean: return .SwiftBool
      case .byte: return .SwiftInt8
      case .char: return .SwiftUInt16
      case .short: return .SwiftInt16
      case .int: return .SwiftInt32
      case .long: return .SwiftInt64
      case .float: return .SwiftFloat
      case .double: return .SwiftDouble
      case .array, .class, .void: fatalError("Not a primitive type")
      }

    case .int:
      return .SwiftInt

    case .heapObject, .cFunction:
      return .SwiftPointer
    }
  }
}

enum TypeTranslationError: Error {
  /// We haven't yet implemented support for this type.
  case unimplementedType(TypeSyntax)

  /// Unexpected generic arguments.
  case unexpectedGenericArguments(TypeSyntax, [TranslatedType])

  /// Missing generic arguments.
  case missingGenericArguments(TypeSyntax)

  /// Type syntax nodes cannot be mapped.
  case nestedType(TypeSyntax)
}
