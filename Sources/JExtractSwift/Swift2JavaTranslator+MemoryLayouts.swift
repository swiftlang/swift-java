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

import Foundation
import SwiftBasicFormat
import SwiftParser
import SwiftSyntax

extension Swift2JavaTranslator {

  public func javaMemoryLayoutDescriptors(
    forParametersOf decl: ImportedFunc,
    paramPassingStyle: SelfParameterVariant?
  ) -> [ForeignValueLayout] {
    var layouts: [ForeignValueLayout] = []
    layouts.reserveCapacity(decl.parameters.count + 1)

    for param in decl.effectiveParameters(paramPassingStyle: paramPassingStyle) {
      if param.type.cCompatibleJavaMemoryLayout == CCompatibleJavaMemoryLayout.primitive(.void) {
        continue
      }

      var layout = param.type.foreignValueLayout
      layout.inlineComment = "\(param.effectiveValueName)"
      layouts.append(layout)
    }

    // an indirect return passes the buffer as the last parameter to our thunk
    if decl.isIndirectReturn {
      var layout = ForeignValueLayout.SwiftPointer
      layout.inlineComment = "indirect return buffer"
      layouts.append(layout)
    }

    return layouts
  }
}
