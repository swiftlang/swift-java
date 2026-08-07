//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CodePrinting
import SwiftExtract
import SwiftJavaJNICore

extension JNISwift2JavaGenerator {

  /// Emit `@JavaInterface` Swift wrappers for each `@escaping` closure
  /// parameter of the passed in function.
  ///
  /// The wrapper's purpose is to retain the Java side object and delegate the calls on it to
  /// the Java object "callback".
  /// Each wrapper has it's corresponding Java side printed by `printJavaBindingWrapperHelperClass`.
  func printEscapingClosureSwiftFunctionHelperClasses(
    _ printer: inout SwiftPrinter,
    _ translatedDecl: TranslatedFunctionDecl,
  ) {
    for ty in translatedDecl.functionTypes {
      guard let closureTy = ty.syntheticClosureType else {
        continue
      }
      printEscapingClosureWrapJavaInterface(&printer, closureTy)
    }
  }

  private func printEscapingClosureWrapJavaInterface(
    _ printer: inout SwiftPrinter,
    _ closureTy: SyntheticEscapingClosureFunctionType,
  ) {
    printer.printBraceBlock(
      """
      @JavaInterface("\(closureTy.javaBinaryName)")
      public struct \(closureTy.javaInterfaceName)
      """
    ) { p in
      let signature = self.renderEscapingClosureApplySignature(closureTy.functionType)
      p.print(
        """
        @JavaMethod
        public func apply\(signature)
        """
      )
    }
    printer.println()
  }

  private func renderEscapingClosureApplySignature(_ type: SwiftFunctionType) -> String {
    let params = type.parameters.enumerated().map { idx, param -> String in
      let name = param.parameterName ?? "_\(idx)"
      let typeName = param.type.description
      return "_ \(name): \(typeName)"
    }
    let paramList = "(\(params.joined(separator: .comma)))"

    if type.resultType.isVoid {
      return paramList
    } else {
      return "\(paramList) -> \(type.resultType.description)"
    }
  }
}
