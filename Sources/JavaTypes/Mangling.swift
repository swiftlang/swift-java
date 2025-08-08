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

extension JavaType {
  /// Demangle a Java type name into a representation of the type.
  public init(mangledName: String) throws {
    var mangledName = mangledName[...]
    self = try JavaType.demangleNextType(from: &mangledName)
    if !mangledName.isEmpty {
      throw JavaDemanglingError.extraText(String(mangledName))
    }
  }

  /// Produce a Java mangled type name for this type.
  public var mangledName: String {
    switch self {
    case .boolean: "Z"
    case .byte: "B"
    case .char: "C"
    case .double: "D"
    case .float: "F"
    case .int: "I"
    case .long: "J"
    case .short: "S"
    case .void: "V"
    case .array(let elementType): "[" + elementType.mangledName
    case .class(package: let package, name: let name):
      "L\(package!).\(name.replacingPeriodsWithDollars());".replacingPeriodsWithSlashes()
    }
  }
}

extension MethodSignature {
  /// Demangle the given method Java signature.
  public init(mangledName: String) throws {
    // Method signatures have the form "(parameter-types)result-type".
    guard mangledName.starts(with: "(") else {
      throw JavaDemanglingError.invalidMangledName(mangledName)
    }
    var remainingName = mangledName.dropFirst()

    // Demangle the parameter types.
    var parameterTypes: [JavaType] = []
    while let firstChar = remainingName.first, firstChar != ")" {
      let parameterType = try JavaType.demangleNextType(from: &remainingName)
      parameterTypes.append(parameterType)
    }
    self.parameterTypes = parameterTypes

    guard remainingName.first == ")" else {
      throw JavaDemanglingError.invalidMangledName(mangledName)
    }

    // Demangle the result type.
    remainingName = remainingName.dropFirst()
    self.resultType = try JavaType(mangledName: String(remainingName))
  }

  /// Produce a mangled name for this method signature.
  public var mangledName: String {
    var result = "("
    for parameterType in parameterTypes {
      result += parameterType.mangledName
    }
    result += ")"
    result += resultType.mangledName
    return result
  }
}

extension JavaType {
  /// Demangle the next Java type from the given string, shrinking the input
  /// string and producing demangled type.
  static func demangleNextType(from string: inout Substring) throws -> JavaType {
    guard let firstChar = string.first else {
      throw JavaDemanglingError.invalidMangledName(String(string))
    }

    switch firstChar {
    case "Z": string = string.dropFirst(); return .boolean
    case "B": string = string.dropFirst(); return .byte
    case "C": string = string.dropFirst(); return .char
    case "D": string = string.dropFirst(); return .double
    case "F": string = string.dropFirst(); return .float
    case "I": string = string.dropFirst(); return .int
    case "J": string = string.dropFirst(); return .long
    case "S": string = string.dropFirst(); return .short
    case "V": string = string.dropFirst(); return .void
    case "[":
      // Count the brackets to determine array depth.
      var arrayDepth = 1
      string = string.dropFirst()
      while string.first == "[" {
        arrayDepth += 1
        string = string.dropFirst()
      }

      var resultType = try demangleNextType(from: &string)
      while arrayDepth > 0 {
        resultType = .array(resultType)
        arrayDepth -= 1
      }

      return resultType

    case "L":
      guard let semicolonIndex = string.firstIndex(of: ";") else {
        throw JavaDemanglingError.invalidMangledName(String(string))
      }

      // Extract the canonical Java class name with the slashes in it.
      let afterStart = string.index(after: string.startIndex)
      let canonicalNameWithSlashes = string[afterStart..<semicolonIndex]
      string = string[string.index(after: semicolonIndex)...]

      return JavaType(
        className: canonicalNameWithSlashes.replacingSlashesWithPeriods()
      )

    default:
      throw JavaDemanglingError.invalidMangledName(String(string))
    }
  }
}

extension StringProtocol {
  /// Return the string after replacing all of the periods (".") with slashes ("/").
  fileprivate func replacingPeriodsWithSlashes() -> String {
    return String(self.map { $0 == "." ? "/" as Character : $0 })
  }

  /// Return the string after replacing all of the forward slashes ("/") with
  /// periods (".").
  fileprivate func replacingSlashesWithPeriods() -> String {
    return String(self.map { $0 == "/" ? "." as Character : $0 })
  }

  /// Return the string after replacing all of the periods (".") with slashes ("$").
  fileprivate func replacingPeriodsWithDollars() -> String {
    return String(self.map { $0 == "." ? "$" as Character : $0 })
  }
}
