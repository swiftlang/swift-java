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

import SwiftSyntax
import SwiftSyntaxBuilder

enum SwiftKnownModule: String {
  case swift = "Swift"
  case foundation = "Foundation"
  case foundationEssentials = "FoundationEssentials"

  var name: String {
    self.rawValue
  }

  var symbolTable: SwiftModuleSymbolTable {
    switch self {
    case .swift: swiftSymbolTable
    case .foundation: foundationSymbolTable
    case .foundationEssentials: foundationEssentialsSymbolTable
    }
  }

  var sourceFile: SourceFileSyntax {
    switch self {
    case .swift: swiftSourceFile
    case .foundation: foundationEssentialsSourceFile
    case .foundationEssentials: foundationEssentialsSourceFile
    }
  }
}

private var swiftSymbolTable: SwiftModuleSymbolTable {
  var builder = SwiftParsedModuleSymbolTableBuilder(moduleName: "Swift", importedModules: [:])
  builder.handle(sourceFile: swiftSourceFile, sourceFilePath: "SwiftStdlib.swift")  // FIXME: missing path here
  return builder.finalize()
}

private var foundationEssentialsSymbolTable: SwiftModuleSymbolTable {
  var builder = SwiftParsedModuleSymbolTableBuilder(
    moduleName: "FoundationEssentials",
    requiredAvailablityOfModuleWithName: "FoundationEssentials",
    alternativeModules: .init(isMainSourceOfSymbols: false, moduleNames: ["Foundation"]),
    importedModules: ["Swift": swiftSymbolTable]
  )
  builder.handle(sourceFile: foundationEssentialsSourceFile, sourceFilePath: "FakeFoundation.swift")
  return builder.finalize()
}

private var foundationSymbolTable: SwiftModuleSymbolTable {
  var builder = SwiftParsedModuleSymbolTableBuilder(
    moduleName: "Foundation",
    alternativeModules: .init(isMainSourceOfSymbols: true, moduleNames: ["FoundationEssentials"]),
    importedModules: ["Swift": swiftSymbolTable]
  )
  builder.handle(sourceFile: foundationSourceFile, sourceFilePath: "Foundation.swift")
  return builder.finalize()
}

private let swiftSourceFile: SourceFileSyntax = """
  public struct Bool {}
  public struct Int {}
  public struct UInt {}
  public struct Int8 {}
  public struct UInt8 {}
  public struct Int16 {}
  public struct UInt16 {}
  public struct Int32 {}
  public struct UInt32 {}
  public struct Int64 {}
  public struct UInt64 {}
  public struct Float {}
  public struct Double {}

  public struct UnsafeRawPointer {}
  public struct UnsafeMutableRawPointer {}
  public struct UnsafeRawBufferPointer {}
  public struct UnsafeMutableRawBufferPointer {}

  public struct UnsafePointer<Pointee> {}
  public struct UnsafeMutablePointer<Pointee> {}

  public struct UnsafeBufferPointer<Element> {}
  public struct UnsafeMutableBufferPointer<Element> {}

  public struct Optional<Wrapped> {}

  public struct Array<Element> {}

  // FIXME: Support 'typealias Void = ()'
  public struct Void {}

  public struct String {
    public init(cString: UnsafePointer<Int8>)
    public func withCString(_ body: (UnsafePointer<Int8>) -> Void)
  }
  """

private let foundationEssentialsSourceFile: SourceFileSyntax = """
  public protocol DataProtocol {}

  public struct Data: DataProtocol {
    public init(bytes: UnsafeRawPointer, count: Int)
    public init(_ bytes: [UInt8])
    public var count: Int { get }
    public func withUnsafeBytes(_ body: (UnsafeRawBufferPointer) -> Void)
  }

  public struct Date {
    /// The interval between the date object and 00:00:00 UTC on 1 January 1970.
    public var timeIntervalSince1970: Double { get }

    /// Returns a `Date` initialized relative to 00:00:00 UTC on 1 January 1970 by a given number of seconds.
    public init(timeIntervalSince1970: Double)
  }

  public struct UUID {}
  """

private var foundationSourceFile: SourceFileSyntax {
  // On platforms other than Darwin, imports such as FoundationEssentials, FoundationNetworking, etc. are used,
  // so this file should be created by combining the files of the aforementioned modules.
  foundationEssentialsSourceFile
}
