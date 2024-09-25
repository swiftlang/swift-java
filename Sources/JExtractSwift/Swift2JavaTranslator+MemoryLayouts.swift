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

import Foundation
import SwiftBasicFormat
import SwiftParser
import SwiftSyntax

let SWIFT_POINTER = "SWIFT_POINTER"

extension Swift2JavaTranslator {
  public func javaMemoryLayoutDescriptors(
    forParametersOf decl: ImportedFunc,
    selfVariant: SelfParameterVariant?
  ) -> [ForeignValueLayout] {
    var layouts: [ForeignValueLayout] = []
    layouts.reserveCapacity(decl.parameters.count + 1)

    //     // When the method is `init()` it does not accept a self (well, unless allocating init but we don't import those)
    //    let selfVariant: SelfParameterVariant? =
    //      decl.isInit ? nil : .wrapper

    for param in decl.effectiveParameters(selfVariant: selfVariant) {
      if let paramLayout = javaMemoryLayoutDescriptor(param.type) {
        layouts.append(paramLayout)
      }
    }

    return layouts
  }

  // This may reach for another types $layout I think
  public func javaMemoryLayoutDescriptor(_ ty: ImportedTypeName) -> ForeignValueLayout? {
    switch ty.swiftTypeName {
    case "Bool":
      return .SwiftBool
    case "Int":
      return .SwiftInt
    case "Int32":
      return .SwiftInt32
    case "Int64":
      return .SwiftInt64
    case "Float":
      return .SwiftFloat
    case "Double":
      return .SwiftDouble
    case "Void":
      return nil
    case "Never":
      return nil
    case "Swift.UnsafePointer<Swift.UInt8>":
      return .SwiftPointer
    default:
      break
    }

    // not great?
    if ty.swiftTypeName == "Self.self" {
      return .SwiftPointer
    }

    // not great?
    if ty.swiftTypeName == "(any Any.Type)?" {
      return .SwiftPointer
    }

    if ty.swiftTypeName == "() -> ()" {
      return .SwiftPointer
    }

    // TODO: Java has OptionalLong, OptionalInt, OptionalDouble types.
    // if ty.swiftTypeName.hasSuffix("?") {
    // if ty.swiftTypeName == "Int?" {
    //   return JavaOptionalLong
    // } else ..
    // }

    // Last fallback is to try to get the type's $layout()
    return ForeignValueLayout(inlineComment: ty.swiftTypeName, customType: ty.fullyQualifiedName)
  }
}
