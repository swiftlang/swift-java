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
import _Subprocess

/// Hacky way to get hold of symbols until swift interfaces can include them.
package struct SwiftDylib {  // FIXME: remove this entire utility; replace with more rich .swiftinterface files
  let path: String
  var log: Logger

  package init?(path: String) {
    guard FileManager.default.fileExists(atPath: path) else {
      return nil
    }

    self.path = path
    self.log = Logger(label: "SwiftDylib(\(path))", logLevel: .trace)  // TODO: take from env
  }

  package func fillInTypeMangledName(_ decl: ImportedNominalType) async throws -> ImportedNominalType {
    // TODO: this is hacky, not precise at all and will be removed entirely
    guard decl.swiftMangledName == nil else {
      // it was already processed
      return decl
    }

    var decl = decl
    let names = try await nmSymbolNames(grepDemangled: [
      decl.swiftTypeName,
      "type metadata for",
    ])
    if let name = names.first {
      log.trace("Selected mangled name for '\(decl.javaType.description)': \(name)")
      decl.swiftMangledName = name.mangledName
    }

    return decl
  }

  package func fillInMethodMangledName(_ decl: ImportedFunc) async throws -> ImportedFunc {
    // TODO: this is hacky, not precise at all and will be removed entirely
    guard decl.swiftMangledName.isEmpty else {
      // it was already processed
      return decl
    }

    var decl = decl
    let names = try await nmSymbolNames(grepDemangled: [decl.baseIdentifier])
    if let name = names.first {
      log.trace("Selected mangled name for '\(decl.identifier)': \(name)")
      decl.swiftMangledName = name.mangledName
    }

    return decl
  }

  package func fillInInitMangledName(_ decl: ImportedFunc) async throws -> ImportedFunc {
    // TODO: this is hacky, not precise at all and will be removed entirely
    guard decl.swiftMangledName.isEmpty else {
      // it was already processed
      return decl
    }

    var decl = decl
    let names = try await nmSymbolNames(grepDemangled: [
      decl.returnType.swiftTypeName,
      ".init(",
    ])
    if let name = names.first {
      log.trace("Selected mangled name for '\(decl.identifier)': \(name)")
      decl.swiftMangledName = name.mangledName
    }

    return decl
  }

  package func fillInAllocatingInitMangledName(_ decl: ImportedFunc) async throws -> ImportedFunc {
    // TODO: this is hacky, not precise at all and will be removed entirely
    guard decl.swiftMangledName.isEmpty else {
      // it was already processed
      return decl
    }

    var decl = decl
    let names = try await nmSymbolNames(grepDemangled: ["\(decl.parentName!.swiftTypeName)", "__allocating_init("])
    if let name = names.first {
      log.trace("Selected mangled name: \(name)")
      decl.swiftMangledName = name.mangledName
    }

    return decl
  }

  /// Note that this is just a hack / workaround until swiftinterface files contain mangled names/
  /// So not even trying to make this very efficient. We find the symbols from the dylib and some
  /// heuristic matching.
  package func nmSymbolNames(grepDemangled: [String]) async throws -> [SwiftSymbolName] {
    #if os(Linux)
    #warning("Obtaining symbols with 'nm' is not supported on Linux and about to be removed in any case")
    return []
    #endif

    // -----

    let nmResult = try await Subprocess.run(
      .named("nm"),
      arguments: ["-gU", path]
    )

    print(">>> nm -gU \(path)")

    let nmOutput = String(
      data: nmResult.standardOutput,
      encoding: .utf8
    )!
    let nmLines = nmOutput.split(separator: "\n")

    let demangledOutput = try await swiftDemangle(nmOutput)
    let demangledLines = demangledOutput.split(separator: "\n")

    var results: [SwiftSymbolName] = []
    for (sym, dem) in zip(nmLines, demangledLines)
    where grepDemangled.allSatisfy({ g in dem.contains(g) }) {
      guard let mangledName = sym.split(separator: " ").last else {
        continue
      }

      let descriptiveName = dem.split(separator: " ").dropFirst(2).joined(separator: " ")

      let name = SwiftSymbolName(
        mangledName: String(mangledName),
        descriptiveName: descriptiveName
      )
      results.append(name)
    }

    return results
  }

  package func swiftDemangle(_ input: String) async throws -> String {
    let input = input.utf8CString.map { UInt8($0) }

    let demangleResult = try await Subprocess.run(
      .named("swift"),
      arguments: ["demangle"],
      input: input
    )

    let demangledOutput = String(
      data: demangleResult.standardOutput,
      encoding: .utf8
    )!

    return demangledOutput
  }
}

package struct SwiftSymbolName {
  package let mangledName: String
  package let descriptiveName: String

  init(mangledName: String, descriptiveName: String) {
    self.mangledName = String(mangledName.trimmingPrefix("_"))
    self.descriptiveName = descriptiveName
  }
}

extension Array {
  func flatten<T>() -> Array<Element> where Element == Optional<T> {
    self.compactMap { $0 }
  }
}

// Those are hacky ways to find symbols, all this should be deleted and we should use metadata from swiftinterface files
package extension Collection where Element == SwiftSymbolName {
  func findInit() -> SwiftSymbolName? {
    self.first {
      $0.descriptiveName.contains(".init(")
    }
  }

  func findAllocatingInit() -> SwiftSymbolName? {
    self.first {
      $0.descriptiveName.contains(".__allocating_init(")
    }
  }

  func findPropertyGetter() -> SwiftSymbolName? {
    self.first {
      $0.descriptiveName.contains(".getter : ")
    }
  }

  func findPropertySetter() -> SwiftSymbolName? {
    self.first {
      $0.descriptiveName.contains(".setter : ")
    }
  }
}
