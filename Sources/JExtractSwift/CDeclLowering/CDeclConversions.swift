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

extension ConversionStep {
  /// Produce a conversion that takes in a value (or set of values) that
  /// would be available in a @_cdecl function to represent the given Swift
  /// type, and convert that to an instance of the Swift type.
  init(cdeclToSwift swiftType: SwiftType) throws {
    switch swiftType {
    case .function, .optional:
      throw LoweringError.unhandledType(swiftType)

    case .metatype(let instanceType):
      self = .unsafeCastPointer(
        .placeholder,
        swiftType: instanceType
      )

    case .nominal(let nominal):
      if let knownType = nominal.nominalTypeDecl.knownStandardLibraryType {
        // Swift types that map to primitive types in C. These can be passed
        // through directly.
        if knownType.primitiveCType != nil {
          self = .placeholder
          return
        }

        // Typed pointers
        if let firstGenericArgument = nominal.genericArguments?.first {
          switch knownType {
          case .unsafePointer, .unsafeMutablePointer:
            self = .typedPointer(
              .explodedComponent(.placeholder, component: "pointer"),
              swiftType: firstGenericArgument
            )
            return

          case .unsafeBufferPointer, .unsafeMutableBufferPointer:
            self = .initialize(
              swiftType,
              arguments: [
                LabeledArgument(
                  label: "start",
                  argument: .typedPointer(
                    .explodedComponent(.placeholder, component: "pointer"),
                    swiftType: firstGenericArgument)
                ),
                LabeledArgument(
                  label: "count",
                  argument: .explodedComponent(.placeholder, component: "count")
                )
              ]
            )
            return

          default:
            break
          }
        }
      }

      // Arbitrary nominal types.
      switch nominal.nominalTypeDecl.kind {
      case .actor, .class:
        // For actor and class, we pass around the pointer directly.
        self = .unsafeCastPointer(.placeholder, swiftType: swiftType)
      case .enum, .struct, .protocol:
        // For enums, structs, and protocol types, we pass around the
        // values indirectly.
        self = .passIndirectly(
          .pointee(.typedPointer(.placeholder, swiftType: swiftType))
        )
      }

    case .tuple(let elements):
      self = .tuplify(try elements.map { try ConversionStep(cdeclToSwift: $0) })
    }
  }
}
