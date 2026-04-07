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

import SwiftJavaConfigurationShared
import SwiftJavaJNICore

/// Determine if the given type needs any extra annotations that should be included
/// in Java sources when the corresponding Java type is rendered.
func getJavaTypeAnnotations(swiftType: SwiftType, config: Configuration) -> [JavaAnnotation] {
  if swiftType.isUnsignedInteger {
    return [JavaAnnotation.unsigned]
  }

  switch swiftType.asNominalType?.asKnownType {
  case .array(let element) where element.isUnsignedInteger:
    return [JavaAnnotation.unsigned]
  case .array(let element): // check recursively for [[UInt8]] etc
    return getJavaTypeAnnotations(swiftType: element, config: config)

  case .set(let element) where element.isUnsignedInteger:
    return [JavaAnnotation.unsigned]
  case .set(let element):
    return getJavaTypeAnnotations(swiftType: element, config: config)

  case .dictionary(let key, let value) where key.isUnsignedInteger || value.isUnsignedInteger:
    return [JavaAnnotation.unsigned]
  case .dictionary(let key, let value):
    return getJavaTypeAnnotations(swiftType: key, config: config) + getJavaTypeAnnotations(swiftType: value, config: config)

  default:
    return []
  }
}
