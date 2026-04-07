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

import SwiftJavaJNICore

extension JNISwift2JavaGenerator.TranslatedFunctionDecl {

  /// Returns any used labeled tuple types that this function uses
  var usedLabeledTuples: [JavaType] {
    var result: [JavaType] = []
    collectLabeledTuples(from: translatedFunctionSignature.resultType.javaType, into: &result)
    for param in translatedFunctionSignature.parameters {
      collectLabeledTuples(from: param.parameter.type.javaType, into: &result)
    }
    return result
  }
}

private func collectLabeledTuples(from type: JavaType, into result: inout [JavaType]) {
  switch type {
  case .class(_, _, let typeParameters):
    if type.isSwiftJavaLabeledTuple {
      result.append(type)
    }
    for ty in typeParameters {
      collectLabeledTuples(from: ty, into: &result)
    }
  case .array(let element):
    collectLabeledTuples(from: element, into: &result)
  default:
    break
  }
}
