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

import SwiftJavaConfigurationShared
import Testing

@testable import JExtractSwiftLib

// ==== -----------------------------------------------------------------------
// MARK: Specialization tests

@Suite
struct SpecializationTests {

  // A generic type with two typealiases targeting the same base,
  // and a constrained extension that only applies to one specialization
  let multiSpecializationInput =
    #"""
    public struct Box<Element> {
      public var items: [Element]

      public init() {
        self.items = []
      }

      public func count() -> Int {
        return items.count
      }
    }

    public struct Fish {
      public var name: String
    }

    public struct Tool {
      public var name: String
    }

    extension Box where Element == Fish {
      public func observeTheFish() {}
    }

    public typealias FishBox = Box<Fish>
    public typealias ToolBox = Box<Tool>
    """#

  // ==== -----------------------------------------------------------------------
  // MARK: importedTypes structure

  @Test("Multiple specializations of same base type produce distinct importedTypes")
  func multipleSpecializationsProduceDistinctTypes() throws {
    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swiftinterface", text: multiSpecializationInput)

    // Both specialized types should be registered
    #expect(translator.importedTypes["FishBox"] != nil, "FishBox should be in importedTypes")
    #expect(translator.importedTypes["ToolBox"] != nil, "ToolBox should be in importedTypes")

    // The base generic type remains in importedTypes (not removed)
    let baseBox = try #require(translator.importedTypes["Box"])
    #expect(!baseBox.isSpecialization, "Base 'Box' should not be a specialization")
    #expect(baseBox.genericParameterNames == ["Element"])
    #expect(baseBox.genericArguments.isEmpty)
    #expect(!baseBox.isFullySpecialized)

    // Specialized types link back to their base
    let fishBox = try #require(translator.importedTypes["FishBox"])
    let toolBox = try #require(translator.importedTypes["ToolBox"])
    #expect(fishBox.isSpecialization)
    #expect(toolBox.isSpecialization)

    // Verify effective names are distinct
    #expect(fishBox.effectiveJavaName == "FishBox")
    #expect(toolBox.effectiveJavaName == "ToolBox")

    #expect(fishBox.effectiveSwiftTypeName == "Box<Fish>")
    #expect(toolBox.effectiveSwiftTypeName == "Box<Tool>")

    // Verify new generic-model properties
    #expect(fishBox.genericParameterNames == ["Element"])
    #expect(fishBox.genericArguments == ["Element": "Fish"])
    #expect(fishBox.isFullySpecialized)
    #expect(fishBox.baseTypeName == "Box")
    #expect(fishBox.specializedTypeName == "FishBox")

    #expect(toolBox.genericParameterNames == ["Element"])
    #expect(toolBox.genericArguments == ["Element": "Tool"])
    #expect(toolBox.isFullySpecialized)
    #expect(toolBox.baseTypeName == "Box")
    #expect(toolBox.specializedTypeName == "ToolBox")

    // Both wrappers delegate to the same base type
    #expect(fishBox.specializationBaseType === toolBox.specializationBaseType, "Both should wrap the same base Box type")
    #expect(fishBox.specializationBaseType === translator.importedTypes["Box"], "Base should be the original Box")
  }

  @Test("Specializations keyed by base type contain all entries")
  func specializationEntriesContainAll() throws {
    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swiftinterface", text: multiSpecializationInput)

    let baseBox = try #require(translator.importedTypes["Box"])
    let specializations = try #require(translator.specializations[baseBox])
    #expect(specializations.count == 2, "Should have exactly 2 specializations for Box")

    let javaNames = specializations.map(\.effectiveJavaName).sorted()
    #expect(javaNames == ["FishBox", "ToolBox"])
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Generated Java classes

  @Test("FishBox Java class has base methods and constrained extension method")
  func fishBoxJavaClass() throws {
    try assertOutput(
      input: multiSpecializationInput,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // Class declaration
        "public final class FishBox implements JNISwiftInstance {",
        // Constructor must use the specialized name, not the base type name
        "private FishBox(long selfPointer, SwiftArena swiftArena)",
        // Factory method must use the specialized name
        "public static FishBox wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena)",
        // Base method from Box<Element>
        "public long count()",
        // Method body must call FishBox's own native method, not Box's
        "FishBox.$count(",
        // Constrained extension method (Element == Fish)
        "public void observeTheFish()",
        // Constrained method body must also call FishBox's native method
        "FishBox.$observeTheFish(",
      ],
    )
  }

  @Test("ToolBox Java class has base methods but not Fish-constrained methods")
  func toolBoxJavaClass() throws {
    try assertOutput(
      input: multiSpecializationInput,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // Class declaration
        "public final class ToolBox implements JNISwiftInstance {",
        // Base method from Box<Element>
        "public long count()",
      ],
    )

    // Verify observeTheFish does NOT appear inside ToolBox's class body
    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(path: "/fake/Fake.swiftinterface", text: multiSpecializationInput)
    let toolBox = try #require(translator.importedTypes["ToolBox"])
    let methodNames = toolBox.methods.map(\.name)
    #expect(!methodNames.contains("observeTheFish"), "ToolBox should not have Fish-constrained method")
  }

  @Test("Single specialization generates expected Java class")
  func singleSpecialization() throws {
    let input =
      #"""
      public struct Box<Element> {
        public var items: [Element]

        public init() {
          self.items = []
        }

        public func count() -> Int {
          return items.count
        }
      }

      public struct Fish {
        public var name: String
      }

      public typealias FishBox = Box<Fish>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishBox implements JNISwiftInstance {",
        "public long count()",
      ],
    )
  }

  @Test("Nested generic specialization generates expected Java class")
  func nestedGenericSpecialization() throws {
    let input =
      #"""
      public struct Box<Element> {
        public var items: [Element]

        public init() {
          self.items = []
        }

        public func count() -> Int {
          return items.count
        }
      }

      public struct Fish {
        public var name: String
      }

      public typealias FishBox = Box<Fish>
      public typealias FishBoxBox = Box<Box<Fish>>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishBox implements JNISwiftInstance {",
        "public final class FishBoxBox implements JNISwiftInstance {",
      ],
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Swift thunks

  @Test("FishBox Swift thunks use direct downcall, not protocol opening")
  func fishBoxSwiftThunks() throws {
    try assertOutput(
      input: multiSpecializationInput,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // FishBox constrained extension method: direct downcall with concrete type
        """
        @_cdecl("Java_com_example_swift_FishBox__00024observeTheFish__JJ")
        public func Java_com_example_swift_FishBox__00024observeTheFish__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, selfTypePointer: jlong) {
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
          let selfPointer$ = UnsafeMutablePointer<Box<Fish>>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          selfPointer$.pointee.observeTheFish()
        }
        """,
        // FishBox base method: also uses direct downcall (not opening protocols)
        """
        @_cdecl("Java_com_example_swift_FishBox__00024count__JJ")
        public func Java_com_example_swift_FishBox__00024count__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, selfTypePointer: jlong) -> jlong {
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
          let selfPointer$ = UnsafeMutablePointer<Box<Fish>>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          return Int64(selfPointer$.pointee.count()).getJNILocalRefValue(in: environment)
        }
        """,
      ],
      // FishBox must NOT use protocol opening — it's a concrete specialization
      notExpectedChunks: [
        "_SwiftModule_FishBox_opener"
      ],
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Error cases

  @Test("Specializing a non-generic type throws an error")
  func specializeNonGenericTypeThrows() throws {
    var config = Configuration()
    config.swiftModule = "SwiftModule"
    let translator = Swift2JavaTranslator(config: config)
    try translator.analyze(
      path: "/fake/Fake.swiftinterface",
      text: """
        public struct Fish {
          public var name: String
        }
        """,
    )

    let fish = try #require(translator.importedTypes["Fish"])
    #expect(!fish.swiftNominal.isGeneric)

    #expect(throws: SpecializationError.self) {
      _ = try fish.specialize(as: "FancyFish", with: ["T": "Int"])
    }

    do {
      _ = try fish.specialize(as: "FancyFish", with: ["T": "Int"])
    } catch let error as SpecializationError {
      #expect(error.message.contains("Unable to specialize non-generic type"))
      #expect(error.message.contains("Fish"))
    }
  }
}
