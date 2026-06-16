//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
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

extension SwiftSymbolTable {
  package func printImportedModules(_ printer: inout CodePrinter) {
    let mainSymbolSourceModules = Set(
      self.importedModules.values.filter { $0.alternativeModules?.isMainSourceOfSymbols ?? false }.map(\.moduleName)
    )

    for module in self.importedModules.keys.sorted() {
      guard module != "Swift" else {
        continue
      }

      // Synthetic stub modules (e.g. <javaClassStubs>) exist purely for
      // symbol-table resolution; they are not real Swift modules and must
      // not be emitted as `import` statements.
      guard !self.syntheticImportedModuleNames.contains(module) else {
        continue
      }

      guard let alternativeModules = self.importedModules[module]?.alternativeModules else {
        printer.print("import \(module)")
        continue
      }

      // Only the main source of symbols emits the conditional import block.
      // Secondary modules (e.g. FoundationEssentials when Foundation is the main source)
      // are skipped when their main source is already present, because the main source's
      // block already covers the import. If no main source is present, fall back to a
      // plain import so the module is still imported.
      guard alternativeModules.isMainSourceOfSymbols else {
        if mainSymbolSourceModules.isDisjoint(with: alternativeModules.moduleNames) {
          printer.print("import \(module)")
        }
        continue
      }

      var importGroups: [String: [String]] = [:]
      for name in alternativeModules.moduleNames {
        guard let otherModule = self.importedModules[name] else { continue }

        let groupKey = otherModule.requiredAvailablityOfModuleWithName ?? otherModule.moduleName
        importGroups[groupKey, default: []].append(otherModule.moduleName)
      }

      for (index, group) in importGroups.keys.sorted().enumerated() {
        if index > 0 && importGroups.keys.count > 1 {
          printer.print("#elseif canImport(\(group))")
        } else {
          printer.print("#if canImport(\(group))")
        }

        for groupModule in importGroups[group] ?? [] {
          printer.print("import \(groupModule)")
        }
      }

      if importGroups.keys.isEmpty {
        printer.print("import \(module)")
      } else {
        printer.print("#else")
        printer.print("import \(module)")
        printer.print("#endif")
      }
    }
    printer.println()
  }
}
