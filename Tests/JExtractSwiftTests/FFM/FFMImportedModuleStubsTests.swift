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

import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

@Suite
struct FFMImportedModuleStubsTests {

  // The "main" module source imports an external module and uses its types
  let source = """
    import ExternalModule

    public func makeConfig() -> ExternalModule.Config

    public func takeConfig(_ config: ExternalModule.Config)

    public struct MyStruct {
      public func useConfig(_ config: ExternalModule.Config) -> ExternalModule.Config
    }
    """

  var stubConfig: Configuration {
    var config = Configuration()
    config.importedModuleStubs = [
      "ExternalModule": [
        "public struct Config {}"
      ]
    ]
    return config
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Java bindings

  @Test("Return type from stubbed module generates correct Java binding")
  func returnStubbedType_javaBindings() throws {
    try assertOutput(
      input: source,
      config: stubConfig,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static Config makeConfig("
      ],
    )
  }

  @Test("Parameter from stubbed module generates correct Java binding")
  func takeStubbedType_javaBindings() throws {
    try assertOutput(
      input: source,
      config: stubConfig,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static void takeConfig("
      ],
    )
  }

  @Test("Member method using stubbed type generates correct Java binding")
  func memberUsingStubbedType_javaBindings() throws {
    try assertOutput(
      input: source,
      config: stubConfig,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public Config useConfig("
      ],
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Swift thunks

  @Test("Return type from stubbed module generates correct Swift thunk")
  func returnStubbedType_swiftThunks() throws {
    try assertOutput(
      input: source,
      config: stubConfig,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_makeConfig")
        public func swiftjava_SwiftModule_makeConfig(_ _result: UnsafeMutableRawPointer) {
        """
      ],
    )
  }

  @Test("Parameter from stubbed module generates correct Swift thunk")
  func takeStubbedType_swiftThunks() throws {
    try assertOutput(
      input: source,
      config: stubConfig,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_takeConfig__")
        public func swiftjava_SwiftModule_takeConfig__(_ config: UnsafeRawPointer) {
        """
      ],
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Without stubs, types should not resolve

  @Test("Without stubs, external types are not resolved")
  func withoutStubs_typesNotResolved() throws {
    // Without importedModuleStubs, ExternalModule.Config is unknown
    // and the functions using it should not appear in the output
    try assertOutput(
      input: source,
      .ffm,
      .java,
      expectedChunks: [],
      notExpectedChunks: [
        "makeConfig",
        "takeConfig",
      ],
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Nested types in stubs

  @Test("Nested types in stubbed module")
  func nestedStubbedType_javaBindings() throws {
    let nestedSource = """
      import Networking

      public func getEndpoint() -> Networking.API.Endpoint
      """

    var config = Configuration()
    config.importedModuleStubs = [
      "Networking": [
        "public enum API {}",
        "extension API { public struct Endpoint {} }",
      ]
    ]

    try assertOutput(
      input: nestedSource,
      config: config,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static API.Endpoint getEndpoint("
      ],
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Multiple stubbed modules

  @Test("Multiple stubbed modules resolve correctly")
  func multipleModules_javaBindings() throws {
    let multiSource = """
      import ModuleA
      import ModuleB

      public func convert(_ a: ModuleA.Input) -> ModuleB.Output
      """

    var config = Configuration()
    config.importedModuleStubs = [
      "ModuleA": ["public struct Input {}"],
      "ModuleB": ["public struct Output {}"],
    ]

    try assertOutput(
      input: multiSource,
      config: config,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static Output convert("
      ],
    )
  }
}
