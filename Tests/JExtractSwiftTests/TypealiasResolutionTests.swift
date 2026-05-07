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

import SwiftJavaConfigurationShared
import Testing

@testable import JExtractSwiftLib

@Suite
struct TypealiasResolutionTests {

  // ==== -----------------------------------------------------------------------
  // MARK: Primitive RHS

  let primitiveAliasInput =
    #"""
    public typealias Amount = Double

    public struct TypealiasUser {
      public var amount: Amount

      public init(amount: Amount) {
        self.amount = amount
      }

      public func doubled() -> Amount {
        amount * 2
      }
    }

    public func makeAmount(_ value: Amount) -> Amount {
      value
    }
    """#

  @Test("typealias Amount = Double resolves so struct members are exported")
  func primitiveAliasResolvesStructMembers() throws {
    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: primitiveAliasInput)

    let user = try #require(translator.importedTypes["TypealiasUser"])

    #expect(user.variables.contains { $0.name == "amount" }, "Property `amount: Amount` should be extracted")
    #expect(user.methods.contains { $0.name == "doubled" }, "Method `doubled() -> Amount` should be extracted")
    #expect(!user.initializers.isEmpty, "Initializer `init(amount: Amount)` should be extracted")
  }

  @Test("typealias Amount = Double also unblocks free functions")
  func primitiveAliasResolvesFreeFunc() throws {
    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: primitiveAliasInput)

    #expect(
      translator.importedGlobalFuncs.contains { $0.name == "makeAmount" },
      "Global func `makeAmount(_:)` should be extracted"
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Cross-module nominal RHS

  @Test("typealias to a Swift standard library nominal resolves")
  func aliasToStandardLibraryNominalResolves() throws {
    let input =
      #"""
      public typealias MyInt = Int64

      public struct Holder {
        public var value: MyInt
        public init(value: MyInt) { self.value = value }
      }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let holder = try #require(translator.importedTypes["Holder"])
    #expect(holder.variables.contains { $0.name == "value" })
    #expect(!holder.initializers.isEmpty)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Generic typealias with use-site arguments

  @Test("Generic typealias substitutes type parameters at the use site")
  func genericAliasSubstitutesAtUseSite() throws {
    let input =
      #"""
      public typealias Maybe<T> = Optional<T>

      public func unwrapOrZero(_ value: Maybe<Int64>) -> Int64 {
        value ?? 0
      }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let fn = try #require(translator.importedGlobalFuncs.first { $0.name == "unwrapOrZero" })
    let paramType = try #require(fn.functionSignature.parameters.first?.type)

    // The parameter type should be Optional<Int64> (substituted), preserving
    // the optional sugar — i.e. it must be a nominal Optional whose first
    // generic argument is Swift.Int64.
    guard case .nominal(let nominal) = paramType else {
      Issue.record("Expected paramType to be a nominal type, got \(paramType)")
      return
    }
    #expect(nominal.nominalTypeDecl.name == "Optional")
    let arg0 = try #require(nominal.genericArguments?.first)
    #expect(arg0.description == "Int64", "Expected substituted T to be Int64, got \(arg0)")
  }

  @Test("Multi-parameter generic alias substitutes each parameter independently")
  func multiParameterGenericAliasSubstitutes() throws {
    let input =
      #"""
      public typealias MyDict<K, V> = Dictionary<K, V>

      public func describe(_ dict: MyDict<String, Int64>) -> String {
        "\(dict)"
      }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let fn = try #require(translator.importedGlobalFuncs.first { $0.name == "describe" })
    let paramType = try #require(fn.functionSignature.parameters.first?.type)

    guard case .nominal(let nominal) = paramType else {
      Issue.record("Expected paramType to be a nominal type, got \(paramType)")
      return
    }
    #expect(nominal.nominalTypeDecl.name == "Dictionary")
    let args = try #require(nominal.genericArguments)
    #expect(args.count == 2)
    #expect(args[0].description == "String")
    #expect(args[1].description == "Int64")
  }

  @Test("Use-site arg count mismatch on generic alias is silently dropped")
  func wrongUseSiteArgCountIsDropped() throws {
    let input =
      #"""
      public typealias OneArg<T> = Optional<T>

      public struct Holder {
        // Missing the type argument — invalid Swift, but jextract should
        // silently drop the property rather than crash.
        public var bad: OneArg
      }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let holder = try #require(translator.importedTypes["Holder"])
    #expect(holder.variables.isEmpty, "Property `bad: OneArg` should be dropped (arity mismatch)")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Cycle detection

  @Test("Cyclic typealias chain is silently dropped, no crash")
  func cyclicAliasDoesNotCrash() throws {
    let input =
      #"""
      public typealias A = B
      public typealias B = A

      public struct UsesAlias {
        public var x: A
        public init(x: A) { self.x = x }
      }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    // The struct itself is still imported, but its members are dropped
    // because the alias never resolves.
    let usesAlias = try #require(translator.importedTypes["UsesAlias"])
    #expect(usesAlias.variables.isEmpty, "Property `x: A` should be silently dropped (cycle)")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Generic specialization typealias

  @Test("Existing `typealias FishBox = Box<Fish>` specialization path still fires")
  func genericSpecializationWorks() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }

      public struct Box<Element> {
        public var items: [Element]
        public init() { self.items = [] }
      }

      public typealias FishBox = Box<Fish>
      public func makeFishBox() -> FishBox {
        .init()
      }
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishBox implements JNISwiftInstance {",
        "public static Box<Fish> makeFishBox(",
      ],
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Chained typealiases

  @Test("Typealias chain `A = B; B = C; C = Int64` resolves through all hops")
  func chainedAliasesResolveAllHops() throws {
    let input =
      #"""
      public typealias A = B
      public typealias B = C
      public typealias C = Int64

      public func passA(_ x: A) -> A { x }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let fn = try #require(translator.importedGlobalFuncs.first { $0.name == "passA" })
    let paramType = try #require(fn.functionSignature.parameters.first?.type)
    #expect(
      paramType.description == "Int64",
      "A → B → C → Int64 should fully resolve, got \(paramType)"
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Sugar-preserving aliases

  @Test("Typealias to optional sugar resolves to an optional")
  func aliasToOptionalSugar() throws {
    let input =
      #"""
      public typealias MaybeInt = Int64?

      public func unwrap(_ x: MaybeInt) -> Int64 { x ?? 0 }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let fn = try #require(translator.importedGlobalFuncs.first { $0.name == "unwrap" })
    let paramType = try #require(fn.functionSignature.parameters.first?.type)

    guard case .nominal(let nominal) = paramType else {
      Issue.record("Expected Optional nominal, got \(paramType)")
      return
    }
    #expect(nominal.nominalTypeDecl.name == "Optional")
    #expect(nominal.genericArguments?.first?.description == "Int64")
  }

  @Test("Typealias to array sugar resolves to an array")
  func aliasToArraySugar() throws {
    let input =
      #"""
      public typealias Bytes = [Int8]

      public func first(_ b: Bytes) -> Int8 { b.first ?? 0 }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let fn = try #require(translator.importedGlobalFuncs.first { $0.name == "first" })
    let paramType = try #require(fn.functionSignature.parameters.first?.type)

    guard case .nominal(let nominal) = paramType else {
      Issue.record("Expected Array nominal, got \(paramType)")
      return
    }
    #expect(nominal.nominalTypeDecl.name == "Array")
    #expect(nominal.genericArguments?.first?.description == "Int8")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Conditional compilation aliases

  @Test("Typealias inside `#if` resolves the active branch")
  func aliasInsideIfConfigResolvesActiveBranch() throws {
    // jextract's default build configuration treats every `os(...)` check as
    // active, so the first `#if` clause wins. Here that's `Amount = Int64`.
    let input =
      #"""
      #if os(Android)
      public typealias Amount = Int64
      #else
      public typealias Amount = Double
      #endif

      public func add(_ a: Amount, _ b: Amount) -> Amount { a + b }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let fn = try #require(translator.importedGlobalFuncs.first { $0.name == "add" })
    let paramType = try #require(fn.functionSignature.parameters.first?.type)
    #expect(
      paramType.description == "Int64",
      "Active `#if` branch should bind Amount = Int64, got \(paramType)"
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Aliases used as method parameter / return types inside a type

  @Test("Typealias used in a method signature resolves through the lookup")
  func aliasInsideMethodSignatureResolves() throws {
    let input =
      #"""
      public typealias Score = Int64

      public class Player {
        public var score: Score
        public init(score: Score) { self.score = score }
        public func bump(by delta: Score) -> Score {
          score += delta
          return score
        }
      }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let player = try #require(translator.importedTypes["Player"])
    let bump = try #require(player.methods.first { $0.name == "bump" })
    let paramType = try #require(bump.functionSignature.parameters.first?.type)
    #expect(paramType.description == "Int64")
    #expect(bump.functionSignature.result.type.description == "Int64")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Generic alias resolved transitively

  @Test("Generic typealias whose RHS is itself an alias resolves through both")
  func genericAliasOverPlainAlias() throws {
    let input =
      #"""
      public typealias Bag<T> = Optional<T>
      public typealias IntBag = Bag<Int64>

      public func openIntBag(_ b: IntBag) -> Int64 { b ?? 0 }
      """#

    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swift", text: input)

    let fn = try #require(translator.importedGlobalFuncs.first { $0.name == "openIntBag" })
    let paramType = try #require(fn.functionSignature.parameters.first?.type)
    guard case .nominal(let nominal) = paramType else {
      Issue.record("Expected Optional nominal, got \(paramType)")
      return
    }
    #expect(nominal.nominalTypeDecl.name == "Optional")
    #expect(nominal.genericArguments?.first?.description == "Int64")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Nested typealiases

  @Test("Typealias nested inside a type resolves correctly")
  func nestedTypealiasResolves() throws {
    let input =
      #"""
      public struct Foo {
        public typealias ID = Int
        public var id: ID
      }

      public func useFooID(value: Foo.ID) -> Foo.ID {
        value
      }
      """#

    try assertOutput(
      input: input,
      .jni,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        #"""
        @_cdecl("Java_com_example_swift_Foo__00024getId__J")
        public func Java_com_example_swift_Foo__00024getId__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
        """#,
        #"""
        @_cdecl("Java_com_example_swift_Foo__00024setId__JJ")
        public func Java_com_example_swift_Foo__00024setId__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, selfPointer: jlong) {
        """#,
      ],
    )

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public long getId()
        """,
        """
        public void setId(long newValue) 
        """,
        """
        public static long useFooID(long value)
        """,
      ],
    )
  }

  @Test("Nested typealias used in an extension of that typealias's RHS resolves")
  func useNestedTypealiasFromExtension() throws {
    let input =
      #"""
      public typealias MyEnumAlt = Never

      extension MyStruct.MyEnumAlt {
        public func methodInExtension() {}
      }

      public struct MyStruct {
        public enum MyEnum {}
        public typealias MyEnumAlt = MyEnum
      }
      """#

    try assertOutput(
      input: input,
      .ffm,
      .java,
      expectedChunks: [
        #"""
        private static final MemorySegment ADDR =
         SwiftModule.findOrThrow("swiftjava_SwiftModule_MyStruct_MyEnum_methodInExtension");
        """#,
      ],
    )
  }
}
