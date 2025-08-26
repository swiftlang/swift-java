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

extension SwiftType {
  /// Returns a concrete type if this is a generic parameter in the list and it
  /// conforms to a protocol with representative concrete type.
  func representativeConcreteTypeIn(
    knownTypes: SwiftKnownTypes,
    genericParameters: [SwiftGenericParameterDeclaration],
    genericRequirements: [SwiftGenericRequirement]
  ) -> SwiftType? {
    return representativeConcreteType(
      self,
      knownTypes: knownTypes,
      genericParameters: genericParameters,
      genericRequirements: genericRequirements
    )
  }

  /// Returns the protocol type if this is a generic parameter in the list
  func typeIn(
    genericParameters: [SwiftGenericParameterDeclaration],
    genericRequirements: [SwiftGenericRequirement]
  ) -> SwiftType? {
    switch self {
    case .genericParameter(let genericParam):
      if genericParameters.contains(genericParam) {
        let types: [SwiftType] = genericRequirements.compactMap {
          guard case .inherits(let left, let right) = $0, left == self else {
            return nil
          }
          return right
        }

        if types.isEmpty {
          // TODO: Any??
          return nil
        } else if types.count == 1 {
          return types.first!
        } else {
          return .composite(types)
        }
      }

      return nil

    default:
      return nil
    }
  }
}

private func representativeConcreteType(
  _ type: SwiftType,
  knownTypes: SwiftKnownTypes,
  genericParameters: [SwiftGenericParameterDeclaration],
  genericRequirements: [SwiftGenericRequirement]
) -> SwiftType? {
  var maybeProto: SwiftType? = nil
  switch type {
  case .existential(let proto), .opaque(let proto):
    maybeProto = proto
  case .genericParameter(let genericParam):
    // If the type is a generic parameter declared in this function and
    // conforms to a protocol with representative concrete type, use it.
    if genericParameters.contains(genericParam) {
      for requirement in genericRequirements {
        if case .inherits(let left, let right) = requirement, left == type {
          guard maybeProto == nil else {
            // multiple requirements on the generic parameter.
            return nil
          }
          maybeProto = right
          break
        }
      }
    }
  default:
    return nil
  }

  if let knownProtocol = maybeProto?.asNominalTypeDeclaration?.knownTypeKind {
    return knownTypes.representativeType(of: knownProtocol)
  }
  return nil
}
