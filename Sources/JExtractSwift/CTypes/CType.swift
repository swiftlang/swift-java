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

/// Describes a type in the C type system as it is used for lowering of Swift
/// declarations to C.
///
/// This description of the C type system only has to account for the types
/// that are used when providing C-compatible thunks from Swift code. It is
/// not a complete representation of the C type system, and leaves some
/// target-specific types (like the actual type that ptrdiff_t and size_t
/// map to) unresolved.
public enum CType {
  /// A tag type, such as a struct or enum.
  case tag(CTag)

  /// An integral type.
  case integral(IntegralType)

  /// A floating-point type.
  case floating(FloatingType)

  case void

  /// A qualiied type, such as 'const T'.
  indirect case qualified(const: Bool, volatile: Bool, type: CType)

  /// A pointer to the given type.
  indirect case pointer(CType)

  /// A function type.
  indirect case function(resultType: CType, parameters: [CType], variadic: Bool)

  /// An integral type in C, described mostly in terms of the bit-sized
  /// typedefs rather than actual C types (like int or long), because Swift
  /// deals in bit-widths.
  public enum IntegralType {
    case bool

    /// A signed integer type stored with the given number of bits. This
    /// corresponds to the intNNN_t types from <stdint.h>.
    case signed(bits: Int)

    /// An unsigned integer type stored with the given number of bits. This
    /// corresponds to the uintNNN_t types from <stdint.h>.
    case unsigned(bits: Int)

    /// The ptrdiff_t type, which in C is a typedef for the signed integer
    /// type that is the same size as a pointer.
    case ptrdiff_t

    /// The size_t type, which in C is a typedef for the unsigned integer
    /// type that is the same size as a pointer.
    case size_t
  }

  /// A floating point type in C.
  public enum FloatingType {
    case float
    case double
  }
}

extension CType: CustomStringConvertible {
  /// Print the part of this type that comes before the declarator, appending
  /// it to the provided `result` string.
  func printBefore(hasEmptyPlaceholder: inout Bool, result: inout String) {
    // Save the value of hasEmptyPlaceholder and restore it once we're done
    // here.
    let previousHasEmptyPlaceholder = hasEmptyPlaceholder
    defer {
      hasEmptyPlaceholder = previousHasEmptyPlaceholder
    }

    switch self {
    case .floating(let floating):
      switch floating {
      case .float: result += "float"
      case .double: result += "double"
      }

      spaceBeforePlaceHolder(
        hasEmptyPlaceholder: hasEmptyPlaceholder,
        result: &result
      )

    case .function(resultType: let resultType, parameters: _, variadic: _):
      let previousHasEmptyPlaceholder = hasEmptyPlaceholder
      hasEmptyPlaceholder = false
      defer {
        hasEmptyPlaceholder = previousHasEmptyPlaceholder
      }
      resultType.printBefore(
        hasEmptyPlaceholder: &hasEmptyPlaceholder,
        result: &result
      )

      if !previousHasEmptyPlaceholder {
        result += "("
      }

    case .integral(let integral):
      switch integral {
      case .bool: result += "_Bool"
      case .signed(let bits): result += "int\(bits)_t"
      case .unsigned(let bits): result += "uint\(bits)_t"
      case .ptrdiff_t: result += "ptrdiff_t"
      case .size_t: result += "size_t"
      }

      spaceBeforePlaceHolder(
        hasEmptyPlaceholder: hasEmptyPlaceholder,
        result: &result
      )

    case .pointer(let pointee):
      var innerHasEmptyPlaceholder = false
      pointee.printBefore(
        hasEmptyPlaceholder: &innerHasEmptyPlaceholder,
        result: &result
      )
      result += "*"

    case .qualified(const: let isConst, volatile: let isVolatile, type: let underlying):
      if isConst || isVolatile {
        hasEmptyPlaceholder = false
      }

      underlying.printBefore(hasEmptyPlaceholder: &hasEmptyPlaceholder, result: &result)

      // FIXME: "east const" is easier to print correctly, so do that. We could
      // follow Clang and decide when it's correct to print "west const" by
      // splitting the qualifiers before we get here.
      if isConst {
        result += "const"
        hasEmptyPlaceholder = false

        spaceBeforePlaceHolder(
          hasEmptyPlaceholder: hasEmptyPlaceholder,
          result: &result
        )

      }
      if isVolatile {
        result += "volatile"
        hasEmptyPlaceholder = false

        spaceBeforePlaceHolder(
          hasEmptyPlaceholder: hasEmptyPlaceholder,
          result: &result
        )
      }

    case .tag(let tag):
      switch tag {
      case .enum(let cEnum): result += "enum \(cEnum.name)"
      case .struct(let cStruct): result += "struct \(cStruct.name)"
      case .union(let cUnion): result += "union \(cUnion.name)"
      }

      spaceBeforePlaceHolder(
        hasEmptyPlaceholder: hasEmptyPlaceholder,
        result: &result
      )

    case .void:
      result += "void"

      spaceBeforePlaceHolder(
        hasEmptyPlaceholder: hasEmptyPlaceholder,
        result: &result
      )
    }
  }

  /// Render an appropriate "suffix" to the parameter list of a function,
  /// which goes just before the closing ")" of that function, appending
  /// it to the string. This includes whether the function is variadic and
  /// whether is had zero parameters.
  static func printFunctionParametersSuffix(
    isVariadic: Bool,
    hasZeroParameters: Bool,
    to result: inout String
  ) {
    // Take care of variadic parameters and empty parameter lists together,
    // because the formatter of the former depends on the latter.
    switch (isVariadic, hasZeroParameters) {
    case (true, false): result += ", ..."
    case (true, true): result += "..."
    case (false, true): result += "void"
    case (false, false): break
    }
  }

  /// Print the part of the type that comes after the declarator, appending
  /// it to the provided `result` string.
  func printAfter(hasEmptyPlaceholder: inout Bool, result: inout String) {
    switch self {
    case .floating, .integral, .tag, .void: break

    case .function(resultType: let resultType, parameters: let parameters, variadic: let variadic):
      if !hasEmptyPlaceholder {
        result += ")"
      }

      result += "("

      // Render the parameter types.
      result += parameters.map { $0.description }.joined(separator: ", ")

      CType.printFunctionParametersSuffix(
        isVariadic: variadic,
        hasZeroParameters: parameters.isEmpty,
        to: &result
      )

      result += ")"

      var innerHasEmptyPlaceholder = false
      resultType.printAfter(
        hasEmptyPlaceholder: &innerHasEmptyPlaceholder,
        result: &result
      )

    case .pointer(let pointee):
      var innerHasEmptyPlaceholder = false
      pointee.printAfter(
        hasEmptyPlaceholder: &innerHasEmptyPlaceholder,
        result: &result
      )

    case .qualified(const: _, volatile: _, type: let underlying):
      underlying.printAfter(
        hasEmptyPlaceholder: &hasEmptyPlaceholder,
        result: &result
      )
    }
  }

  /// Print this type into a string, with the given placeholder as the name
  /// of the entity being declared.
  public func print(placeholder: String?) -> String {
    var hasEmptyPlaceholder = (placeholder == nil)
    var result = ""
    printBefore(hasEmptyPlaceholder: &hasEmptyPlaceholder, result: &result)
    if let placeholder {
      result += placeholder
    }
    printAfter(hasEmptyPlaceholder: &hasEmptyPlaceholder, result: &result)
    return result
  }

  /// Render the C type into a string that represents the type in C.
  public var description: String {
    print(placeholder: nil)
  }

  private func spaceBeforePlaceHolder(
    hasEmptyPlaceholder: Bool,
    result: inout String
  ) {
    if !hasEmptyPlaceholder {
      result += " "
    }
  }
}

extension CType {
  /// Apply the rules for function parameter decay to produce the resulting
  /// decayed type. For example, this will adjust a function type to a
  /// pointer-to-function type.
  var parameterDecay: CType {
    switch self {
    case .floating, .integral, .pointer, .qualified, .tag, .void: self

    case .function: .pointer(self)
    }
  }
}
