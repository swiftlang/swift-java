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

/// Detects Java method name conflicts caused by Swift overloads that differ
/// only in parameter labels. When a conflict is detected, the affected methods
/// get a camelCase suffix derived from their parameter labels (e.g. `takeValueA`,
/// `takeValueB`) so that Java can distinguish them.
package struct JavaIdentifierFactory {
  private var duplicates: Set<String> = []

  package init() {}

  package init(_ methods: [ImportedFunc]) {
    self.init()
    record(methods)
  }

  /// Analyze the given methods and record any base names that have conflicts.
  private mutating func record(_ methods: [ImportedFunc]) {
    // Group methods by their Java base name.
    var methodsByBaseName: [String: [ImportedFunc]] = [:]
    for method in methods {
      let baseName: String =
        switch method.apiKind {
        case .getter, .subscriptGetter: method.javaGetterName
        case .setter, .subscriptSetter: method.javaSetterName
        case .function, .initializer, .enumCase: method.name
        }
      methodsByBaseName[baseName, default: []].append(method)
    }

    // For each group with 2+ methods, check if any two share the same
    // Swift parameter types (which means identical Java parameter types).
    for (baseName, group) in methodsByBaseName where group.count > 1 {
      var seenSignatures: Set<String> = []
      for method in group {
        let key = method.functionSignature.parameters
          .map { $0.type.description }
          .joined(separator: ",")
        if !seenSignatures.insert(key).inserted {
          duplicates.insert(baseName)
          break
        }
      }
    }
  }

  package func needsSuffix(for baseName: String) -> Bool {
    duplicates.contains(baseName)
  }

  /// Compute the disambiguated Java method name for a declaration.
  package func makeJavaMethodName(_ decl: ImportedFunc) -> String {
    let baseName: String =
      switch decl.apiKind {
      case .getter, .subscriptGetter: decl.javaGetterName
      case .setter, .subscriptSetter: decl.javaSetterName
      case .function, .initializer, .enumCase: decl.name
      }
    return baseName + paramsSuffix(decl, baseName: baseName)
  }

  private func paramsSuffix(_ decl: ImportedFunc, baseName: String) -> String {
    switch decl.apiKind {
    case .getter, .subscriptGetter, .setter, .subscriptSetter:
      return ""
    default:
      guard needsSuffix(for: baseName) else { return "" }
      let labels = decl.functionSignature.parameters
        .compactMap { $0.argumentLabel }
      // A parameterless function that still conflicts (e.g. with a property
      // getter) gets a bare "_" so it compiles as a distinct Java method.
      guard !labels.isEmpty else { return "_" }
      // Join labels in camelCase: takeValue(a:) → takeValueA
      return labels.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
  }
}
