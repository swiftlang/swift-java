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

  var name: String {
    return self.rawValue
  }

  var symbolTable: SwiftModuleSymbolTable {
    return switch self {
    case .swift: swiftSymbolTable
    case .foundation: foundationSymbolTable
    }
  }

  var sourceFile: SourceFileSyntax {
    return switch self {
    case .swift: swiftSourceFile
    case .foundation: foundationSourceFile
    }
  }
}

private var swiftSymbolTable: SwiftModuleSymbolTable {
  var builder = SwiftParsedModuleSymbolTableBuilder(moduleName: "Swift", importedModules: [:])
  builder.handle(sourceFile: swiftSourceFile)
  return builder.finalize()
}

private var foundationSymbolTable: SwiftModuleSymbolTable {
  var builder = SwiftParsedModuleSymbolTableBuilder(moduleName: "Foundation", importedModules: ["Swift": swiftSymbolTable])
  builder.handle(sourceFile: foundationSourceFile)
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
  
  // FIXME: Support 'typealias Void = ()'
  public struct Void {}
  
  public struct String {
    public init(cString: UnsafePointer<Int8>)
    public func withCString(_ body: (UnsafePointer<Int8>) -> Void)
  }
  """

private let foundationSourceFile: SourceFileSyntax = """
  public protocol DataProtocol {}
  
  public struct Data: DataProtocol {
    public init(bytes: UnsafeRawPointer, count: Int)
    public var count: Int { get }
    public func withUnsafeBytes(_ body: (UnsafeRawBufferPointer) -> Void)
  }
  """
