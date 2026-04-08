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

import SwiftJavaConfigurationShared
import SwiftSyntax
import Testing

@testable import JExtractSwiftLib

@Suite
struct JavaTypeAnnotationsTests {

  let knownTypes: SwiftKnownTypes
  let config: Configuration

  init() {
    let symbolTable = SwiftSymbolTable.setup(
      moduleName: "TestModule",
      [SwiftJavaInputFile(syntax: "" as SourceFileSyntax, path: "Fake.swift")],
      config: nil,
      log: Logger(label: "test", logLevel: .critical)
    )
    self.knownTypes = SwiftKnownTypes(symbolTable: symbolTable)
    self.config = Configuration()
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Primitives

  @Test("UInt8 is @Unsigned")
  func uint8_unsigned() {
    let annotations = getJavaTypeAnnotations(swiftType: knownTypes.uint8, config: config)
    #expect(annotations == [.unsigned])
  }

  @Test("Int64 is not @Unsigned")
  func int64_not_unsigned() {
    let annotations = getJavaTypeAnnotations(swiftType: knownTypes.int64, config: config)
    #expect(annotations.isEmpty)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Arrays

  @Test("[UInt8] is @Unsigned")
  func array_uint8_unsigned() {
    let type = knownTypes.arraySugar(knownTypes.uint8)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations == [.unsigned])
  }

  @Test("[Int64] is not @Unsigned")
  func array_int64_not_unsigned() {
    let type = knownTypes.arraySugar(knownTypes.int64)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations.isEmpty)
  }

  @Test("[[UInt8]] is @Unsigned")
  func nested_array_uint8_unsigned() {
    let inner = knownTypes.arraySugar(knownTypes.uint8)
    let type = knownTypes.arraySugar(inner)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations == [.unsigned])
  }

  @Test("[[Int64]] is not @Unsigned")
  func nested_array_int64_not_unsigned() {
    let inner = knownTypes.arraySugar(knownTypes.int64)
    let type = knownTypes.arraySugar(inner)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations.isEmpty)
  }

  @Test("[[[UInt8]]] is @Unsigned (deeply nested)")
  func deeply_nested_array_uint8_unsigned() {
    let inner1 = knownTypes.arraySugar(knownTypes.uint8)
    let inner2 = knownTypes.arraySugar(inner1)
    let type = knownTypes.arraySugar(inner2)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations == [.unsigned])
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Sets

  @Test("Set<UInt8> is @Unsigned")
  func set_uint8_unsigned() {
    let type = knownTypes.set(knownTypes.uint8)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations == [.unsigned])
  }

  @Test("Set<Int64> is not @Unsigned")
  func set_int64_not_unsigned() {
    let type = knownTypes.set(knownTypes.int64)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations.isEmpty)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Dictionaries

  @Test("[UInt8: Int64] is @Unsigned (unsigned key)")
  func dictionary_uint8_key_unsigned() {
    let type = knownTypes.dictionarySugar(knownTypes.uint8, knownTypes.int64)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations == [.unsigned])
  }

  @Test("[Int64: UInt8] is @Unsigned (unsigned value)")
  func dictionary_uint8_value_unsigned() {
    let type = knownTypes.dictionarySugar(knownTypes.int64, knownTypes.uint8)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations == [.unsigned])
  }

  @Test("[Int64: Int32] is not @Unsigned")
  func dictionary_signed_not_unsigned() {
    let type = knownTypes.dictionarySugar(knownTypes.int64, knownTypes.int32)
    let annotations = getJavaTypeAnnotations(swiftType: type, config: config)
    #expect(annotations.isEmpty)
  }
}
