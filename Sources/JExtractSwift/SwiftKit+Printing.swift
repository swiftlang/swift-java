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

/// Helper for printing calls into SwiftKit generated code from generated sources.
package struct SwiftKitPrinting {

  /// Forms syntax for a Java call to a swiftkit exposed function.
  static func renderCallGetSwiftType(module: String, nominal: ImportedNominalType) -> String {
    """
    SwiftKit.swiftjava.getType("\(module)", "\(nominal.swiftTypeName)")
    """
  }
}

// ==== ------------------------------------------------------------------------
// Helpers to form names of "well known" SwiftKit generated functions

extension SwiftKitPrinting {
  enum Names {
  }
}

extension SwiftKitPrinting.Names {
  static func getType(module: String, nominal: ImportedNominalType) -> String {
    "swiftjava_getType_\(module)_\(nominal.swiftTypeName)"
  }

  static func functionThunk(
    thunkNameRegistry: inout ThunkNameRegistry,
    module: String, function: ImportedFunc) -> String {
    let params = function.effectiveParameters(paramPassingStyle: .swiftThunkSelf)
    var paramsPart = ""
    if !params.isEmpty {
      paramsPart = "_" + params.map { param in
        param.firstName ?? "_"
      }.joined(separator: "_")
    }

    let name =
      if let parent = function.parent {
        "swiftjava_\(module)_\(parent.swiftTypeName)_\(function.baseIdentifier)\(paramsPart)"
      } else {
        "swiftjava_\(module)_\(function.baseIdentifier)\(paramsPart)"
      }

    return thunkNameRegistry.deduplicate(name: name)
  }
}
