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

import SwiftJNI
import SwiftJavaConfigurationShared

/// Determine if the given type needs any extra annotations that should be included
/// in Java sources when the corresponding Java type is rendered.
func getTypeAnnotations(swiftType: SwiftType, config: Configuration) -> [JavaAnnotation] {
  if swiftType.isUnsignedInteger, config.effectiveUnsignedNumbersMode == .annotate {
    return [JavaAnnotation.unsigned]
  }

  return []
}
