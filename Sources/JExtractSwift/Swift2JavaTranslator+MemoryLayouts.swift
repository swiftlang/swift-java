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
    selfVariant: SelfParameterVariant?
  ) -> [ForeignValueLayout] {
    var layouts: [ForeignValueLayout] = []
    layouts.reserveCapacity(decl.parameters.count + 1)

    //     // When the method is `init()` it does not accept a self (well, unless allocating init but we don't import those)
    //    let selfVariant: SelfParameterVariant? =
    //      decl.isInit ? nil : .wrapper

    for param in decl.effectiveParameters(selfVariant: selfVariant) {
      layouts.append(param.type.foreignValueLayout)
    }

    return layouts
  }
}
