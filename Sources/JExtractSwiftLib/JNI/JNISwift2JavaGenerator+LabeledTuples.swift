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

import CodePrinting
import SwiftJavaJNICore

extension JNISwift2JavaGenerator {

  /// Print an ad-hoc static inner class for a labeled tuple type.
  ///
  /// Swift labeled tuples look like this: `(x: Int32, y: Int32)`.
  ///
  /// We need to produce a Java class that extends the positional `TupleN` and adds named accessor methods:
  /// ```java
  /// public static class LabeledTuple_fn_x_y<T0, T1>
  ///     extends org.swift.swiftkit.core.tuple.Tuple2<T0, T1> {
  ///
  ///   public LabeledTuple_fn_x_y(T0 param0, T1 param1) { super(param0, param1); }
  ///   public T0 x() { return $0; }
  ///   public T1 y() { return $1; }
  /// }
  /// ```
  func printAdHocLabeledTupleStaticClass(
    _ printer: inout CodePrinter,
    _ labeledTupleType: JavaType
  ) {
    guard labeledTupleType.isSwiftJavaLabeledTuple else {
      return
    }
    guard case .class(_, let rawClassName, let genericArgs) = labeledTupleType else {
      return
    }

    let arity = genericArgs.count
    let elementNames: [String]

    // Element names are embedded in the class name after "LabeledTuple_<baseName>_"
    // We need to extract the last `arity` underscore-separated components
    let parts = rawClassName.split(separator: "_")
    // parts: ["LabeledTuple", baseName, name0, name1, ...]
    // The first part is "LabeledTuple", second is baseName, rest are element names
    if parts.count >= 2 + arity {
      elementNames = parts.suffix(arity).map(String.init)
    } else {
      elementNames = (0..<arity).map { "$\($0)" }
    }

    // Generic type parameter names: T0, T1, ...
    let typeParams = (0..<arity).map { "T\($0)" }
    let typeParamsClause = "<\(typeParams.joined(separator: ", "))>"
    let baseTupleClass = "org.swift.swiftkit.core.tuple.Tuple\(arity)"

    // Constructor parameters: T0 param0, T1 param1, ...
    // Use paramN names (not $0, $1) because `$N` is invalid as a Swift parameter name,
    // and the wrap-java generator copies parameter names verbatim into Swift wrappers
    let paramNames = (0..<arity).map { "param\($0)" }
    let ctorParams = zip(typeParams, paramNames).map { "\($0) \($1)" }.joined(separator: ", ")
    let superArgs = paramNames.joined(separator: ", ")

    printer.printBraceBlock("public static final class \(rawClassName)\(typeParamsClause) extends \(baseTupleClass)\(typeParamsClause)") { printer in
      // Constructor
      printer.print("public \(rawClassName)(\(ctorParams)) { super(\(superArgs)); }")

      // Named accessors
      for (idx, name) in elementNames.enumerated() {
        printer.print("/// Accessor for the \(idx)-nth field of this tuple, named '\(name)'.")
        printer.print("public \(typeParams[idx]) \(name)() { return $\(idx); }")
      }

    }
  }
}
