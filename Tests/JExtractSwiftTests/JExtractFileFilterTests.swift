//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftExtract
import SwiftJavaConfigurationShared
import Testing

@testable import JExtractSwiftLib

// ==== -----------------------------------------------------------------------
// MARK: File-path matching tests

struct JExtractFileFilterTests {

  @Test("File path: exact match")
  func filePathExactMatch() {
    #expect(matchesFilePathFilter(relativePath: "MyType.swift", pattern: "MyType.swift"))
    #expect(!matchesFilePathFilter(relativePath: "MyType.swift", pattern: "OtherType.swift"))
  }

  @Test("File path: exact match with directory")
  func filePathExactMatchWithDirectory() {
    #expect(matchesFilePathFilter(relativePath: "Models/User.swift", pattern: "Models/User.swift"))
    #expect(!matchesFilePathFilter(relativePath: "Models/User.swift", pattern: "Models/Admin.swift"))
  }

  @Test("File path: wildcard suffix in segment")
  func filePathWildcardSuffix() {
    #expect(matchesFilePathFilter(relativePath: "Models/User.swift", pattern: "Models/Us*"))
    #expect(matchesFilePathFilter(relativePath: "Models/UserId.swift", pattern: "Models/Us*"))
    #expect(!matchesFilePathFilter(relativePath: "Models/Admin.swift", pattern: "Models/Us*"))
  }

  @Test("File path: star matches any single segment")
  func filePathStarMatchesAnySegment() {
    #expect(matchesFilePathFilter(relativePath: "Models/User.swift", pattern: "Models/*"))
    #expect(matchesFilePathFilter(relativePath: "Models/Admin.swift", pattern: "Models/*"))
    #expect(!matchesFilePathFilter(relativePath: "Models/Sub/Deep.swift", pattern: "Models/*"))
  }

  @Test("File path: double star recursive wildcard")
  func filePathDoubleStarRecursive() {
    #expect(matchesFilePathFilter(relativePath: "Models/User.swift", pattern: "Models/**"))
    #expect(matchesFilePathFilter(relativePath: "Models/Sub/Deep.swift", pattern: "Models/**"))
    #expect(matchesFilePathFilter(relativePath: "Models/A/B/C.swift", pattern: "Models/**"))
    #expect(!matchesFilePathFilter(relativePath: "Other/User.swift", pattern: "Models/**"))
  }

  @Test("File path: double star matches zero segments")
  func filePathDoubleStarMatchesZero() {
    #expect(matchesFilePathFilter(relativePath: "Models/User.swift", pattern: "**/User.swift"))
    #expect(matchesFilePathFilter(relativePath: "A/B/User.swift", pattern: "**/User.swift"))
    #expect(matchesFilePathFilter(relativePath: "User.swift", pattern: "**/User.swift"))
  }

  @Test("File path: double star in middle of pattern")
  func filePathDoubleStarInMiddle() {
    #expect(matchesFilePathFilter(relativePath: "A/B/C/User.swift", pattern: "A/**/User.swift"))
    #expect(matchesFilePathFilter(relativePath: "A/User.swift", pattern: "A/**/User.swift"))
    #expect(!matchesFilePathFilter(relativePath: "A/B/C/Admin.swift", pattern: "A/**/User.swift"))
  }

  @Test("File path: no match when path is shorter than pattern")
  func filePathNoMatchShorterPath() {
    #expect(!matchesFilePathFilter(relativePath: "Models", pattern: "Models/User.swift"))
  }

  @Test("File path: no match when path is longer than pattern without wildcards")
  func filePathNoMatchLongerPath() {
    #expect(!matchesFilePathFilter(relativePath: "Models/Sub/User.swift", pattern: "Models/User.swift"))
  }

  // ==== -------------------------------------------------------------------
  // MARK: Type-name matching tests

  @Test("Type name: exact match")
  func typeNameExactMatch() {
    #expect(matchesTypeNameFilter(qualifiedName: "MyType", pattern: "MyType"))
    #expect(!matchesTypeNameFilter(qualifiedName: "MyType", pattern: "OtherType"))
  }

  @Test("Type name: nested type with dot separator")
  func typeNameNested() {
    #expect(matchesTypeNameFilter(qualifiedName: "Something.Other", pattern: "Something.Other"))
    #expect(!matchesTypeNameFilter(qualifiedName: "Something.Other", pattern: "Something.Wrong"))
  }

  @Test("Type name: wildcard suffix")
  func typeNameWildcardSuffix() {
    #expect(matchesTypeNameFilter(qualifiedName: "Something.Other", pattern: "Something.Ot*"))
    #expect(!matchesTypeNameFilter(qualifiedName: "Something.Other", pattern: "Something.Wr*"))
  }

  @Test("Type name: star matches any single component")
  func typeNameStarMatchesAny() {
    #expect(matchesTypeNameFilter(qualifiedName: "Something.Other", pattern: "Something.*"))
    #expect(!matchesTypeNameFilter(qualifiedName: "A.B.C", pattern: "A.*"))
  }

  @Test("Type name: double star recursive")
  func typeNameDoubleStarRecursive() {
    #expect(matchesTypeNameFilter(qualifiedName: "A.B.C", pattern: "A.**"))
    #expect(matchesTypeNameFilter(qualifiedName: "A.B", pattern: "A.**"))
    #expect(!matchesTypeNameFilter(qualifiedName: "B.C", pattern: "A.**"))
  }

  @Test("Type name: double star matches zero components")
  func typeNameDoubleStarZero() {
    #expect(matchesTypeNameFilter(qualifiedName: "User", pattern: "**.User"))
    #expect(matchesTypeNameFilter(qualifiedName: "A.B.User", pattern: "**.User"))
  }

  // ==== -------------------------------------------------------------------
  // MARK: Pattern classification tests

  @Test("Pattern classification")
  func patternClassification() {
    #expect(classifyPattern("Models/User.swift") == .filePath)
    #expect(classifyPattern("Models/**") == .filePath)
    #expect(classifyPattern("Something.Other") == .typeName)
    #expect(classifyPattern("MyType") == .plain)
    #expect(classifyPattern("My*") == .plain)

    // Filenames with a Swift source extension are file-path patterns even
    // when they contain a `.`
    #expect(classifyPattern("MyType.swift") == .filePath)
    #expect(classifyPattern("User.swiftinterface") == .filePath)

    // Dotted patterns with `**` are type-name patterns, not file-path
    #expect(classifyPattern("**.Internal") == .typeName)
    #expect(classifyPattern("Outer.**") == .typeName)
    #expect(classifyPattern("Outer.**.Leaf") == .typeName)

    // Bare `**` (no `.` or `/`) is still a file-path wildcard
    #expect(classifyPattern("**") == .filePath)
  }

  // ==== -------------------------------------------------------------------
  // MARK: shouldExtractSwiftFile tests

  @Test("No filters means everything passes")
  func noFilters() {
    var config = Configuration()
    #expect(shouldExtractSwiftFile(relativePath: "Anything.swift", config: config))

    config.swiftFilterInclude = []
    config.swiftFilterExclude = []
    #expect(shouldExtractSwiftFile(relativePath: "Anything.swift", config: config))
  }

  @Test("File include filter only")
  func fileIncludeOnly() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**"]

    #expect(shouldExtractSwiftFile(relativePath: "Models/User.swift", config: config))
    #expect(shouldExtractSwiftFile(relativePath: "Models/Sub/Deep.swift", config: config))
    #expect(!shouldExtractSwiftFile(relativePath: "Other/Thing.swift", config: config))
  }

  @Test("File exclude filter only")
  func fileExcludeOnly() {
    var config = Configuration()
    config.swiftFilterExclude = ["Internal/*"]

    #expect(shouldExtractSwiftFile(relativePath: "Models/User.swift", config: config))
    #expect(!shouldExtractSwiftFile(relativePath: "Internal/Secret.swift", config: config))
  }

  @Test("File include and exclude combined")
  func fileIncludeAndExclude() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**"]
    config.swiftFilterExclude = ["Models/Internal*"]

    #expect(shouldExtractSwiftFile(relativePath: "Models/User.swift", config: config))
    #expect(!shouldExtractSwiftFile(relativePath: "Models/InternalHelper.swift", config: config))
    #expect(!shouldExtractSwiftFile(relativePath: "Other/Thing.swift", config: config))
  }

  @Test("Type-name patterns are ignored by shouldExtractSwiftFile")
  func typeNamePatternsIgnoredByFileFilter() {
    var config = Configuration()
    config.swiftFilterInclude = ["Something.Other"]

    // Type-name-only includes should not restrict file-level filtering
    #expect(shouldExtractSwiftFile(relativePath: "Anything.swift", config: config))
  }

  // ==== -------------------------------------------------------------------
  // MARK: shouldExtractSwiftType tests

  @Test("No filters means all types pass")
  func noFiltersAllTypesPass() {
    let config = Configuration()
    #expect(shouldExtractSwiftType(qualifiedName: "Anything", config: config))
    #expect(shouldExtractSwiftType(qualifiedName: "A.B.C", config: config))
  }

  @Test("Type include filter")
  func typeIncludeFilter() {
    var config = Configuration()
    config.swiftFilterInclude = ["Something.Other"]

    #expect(shouldExtractSwiftType(qualifiedName: "Something.Other", config: config))
    #expect(!shouldExtractSwiftType(qualifiedName: "Something.Wrong", config: config))
  }

  @Test("Type exclude filter")
  func typeExcludeFilter() {
    var config = Configuration()
    config.swiftFilterExclude = ["Something.Internal*"]

    #expect(shouldExtractSwiftType(qualifiedName: "Something.Other", config: config))
    #expect(!shouldExtractSwiftType(qualifiedName: "Something.InternalHelper", config: config))
  }

  @Test("File-path patterns are ignored by shouldExtractSwiftType")
  func filePathPatternsIgnoredByTypeFilter() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**"]

    // File-path-only includes should not restrict type-level filtering
    #expect(shouldExtractSwiftType(qualifiedName: "Anything", config: config))
  }

  @Test("Plain pattern matches both file and type")
  func plainPatternMatchesBoth() {
    var config = Configuration()
    config.swiftFilterInclude = ["MyType"]

    // Plain pattern works at file level (matched against filename segment)
    #expect(shouldExtractSwiftFile(relativePath: "MyType.swift", config: config))
    #expect(!shouldExtractSwiftFile(relativePath: "OtherType.swift", config: config))

    // Plain pattern works at type level
    #expect(shouldExtractSwiftType(qualifiedName: "MyType", config: config))
    #expect(!shouldExtractSwiftType(qualifiedName: "OtherType", config: config))
  }

  @Test("Mixed file and type patterns in same config")
  func mixedPatterns() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**", "Something.Other"]

    // File filter applies the file-path pattern
    #expect(shouldExtractSwiftFile(relativePath: "Models/User.swift", config: config))
    #expect(!shouldExtractSwiftFile(relativePath: "Other/Thing.swift", config: config))

    // Type filter applies the type-name pattern
    #expect(shouldExtractSwiftType(qualifiedName: "Something.Other", config: config))
    #expect(!shouldExtractSwiftType(qualifiedName: "Something.Wrong", config: config))
  }

  // ==== -------------------------------------------------------------------
  // MARK: Config JSON parsing tests

  @Test("jextract filters round-trip through JSON config")
  func filtersFromJSON() throws {
    let json = """
      {
        "javaPackage": "com.example.swift",
        "mode": "jni",
        "swiftFilterInclude": ["Models/**", "Something.Other"],
        "swiftFilterExclude": ["Models/Internal*"]
      }
      """
    let config = try readConfiguration(string: json, configPath: nil)
    #expect(config != nil)
    #expect(config?.swiftFilterInclude == ["Models/**", "Something.Other"])
    #expect(config?.swiftFilterExclude == ["Models/Internal*"])
  }

  @Test("Config without filters has nil filter fields")
  func noFiltersInJSON() throws {
    let json = """
      {
        "javaPackage": "com.example.swift",
        "mode": "jni"
      }
      """
    let config = try readConfiguration(string: json, configPath: nil)
    #expect(config != nil)
    #expect(config?.swiftFilterInclude == nil)
    #expect(config?.swiftFilterExclude == nil)
  }

  @Test("jextract and wrap-java filters are independent in config")
  func independentFilters() throws {
    let json = """
      {
        "swiftFilterInclude": ["Models/**"],
        "javaFilterInclude": ["org.apache.commons"]
      }
      """
    let config = try #require(try readConfiguration(string: json, configPath: nil))
    #expect(config.swiftFilterInclude == ["Models/**"])
    #expect(config.javaFilterInclude == ["org.apache.commons"])
  }

  // Source used by integration tests below: a top-level enum `Tank` containing
  // nested types `Tank.Fish` and `Tank.Internal`, plus a sibling `FishTank`
  static let nestedTypeSource =
    #"""
    public enum Tank {
      public struct Fish {
        public func swim() {}
      }
      public struct Internal {
        public func dontExpose() {}
      }
    }

    public struct FishTank {
      public var capacity: Int = 0
    }
    """#

  private func makeTranslator(
    include: [String]? = nil,
    exclude: [String]? = nil,
  ) throws -> SwiftAnalyzer {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    config.swiftFilterInclude = include
    config.swiftFilterExclude = exclude
    let translator = SwiftAnalyzer(config: config, extractDecider: JavaExtractDecider())
    translator.log.logLevel = .error
    try translator.analyze(path: "Fake.swift", text: Self.nestedTypeSource)
    return translator
  }

  @Test("swiftFilterExclude with exact nested type name")
  func excludeExactNested() throws {
    let st = try makeTranslator(exclude: ["Tank.Internal"])
    #expect(st.importedTypes["Tank"] != nil)
    #expect(st.importedTypes["Tank.Fish"] != nil)
    #expect(st.importedTypes["Tank.Internal"] == nil)
    #expect(st.importedTypes["FishTank"] != nil)
  }

  @Test("swiftFilterExclude with `Type.*` excludes direct children only")
  func excludeDirectChildren() throws {
    let st = try makeTranslator(exclude: ["Tank.*"])
    #expect(st.importedTypes["Tank"] != nil, "Top-level Tank itself should not be excluded by `Tank.*`")
    #expect(st.importedTypes["Tank.Fish"] == nil)
    #expect(st.importedTypes["Tank.Internal"] == nil)
    #expect(st.importedTypes["FishTank"] != nil)
  }

  @Test("swiftFilterExclude with suffix wildcard inside nested name")
  func excludeSuffixWildcard() throws {
    let st = try makeTranslator(exclude: ["Tank.Inter*"])
    #expect(st.importedTypes["Tank"] != nil)
    #expect(st.importedTypes["Tank.Fish"] != nil)
    #expect(st.importedTypes["Tank.Internal"] == nil)
    #expect(st.importedTypes["FishTank"] != nil)
  }

  @Test("swiftFilterExclude with `**.Name` matches at any depth")
  func excludeRecursiveLeaf() throws {
    let st = try makeTranslator(exclude: ["**.Internal"])
    #expect(st.importedTypes["Tank"] != nil)
    #expect(st.importedTypes["Tank.Fish"] != nil)
    #expect(st.importedTypes["Tank.Internal"] == nil)
    #expect(st.importedTypes["FishTank"] != nil)
  }

  @Test("plain-name swiftFilterExclude excludes top-level type and its nested members")
  func excludePlainTopLevel() throws {
    // Plain pattern matches the top-level component, so excluding `Tank` also
    // prevents the visitor from descending into its nested types
    let st = try makeTranslator(exclude: ["Tank"])
    #expect(st.importedTypes["Tank"] == nil)
    #expect(st.importedTypes["Tank.Fish"] == nil)
    #expect(st.importedTypes["Tank.Internal"] == nil)
    #expect(st.importedTypes["FishTank"] != nil)
  }

  @Test("swiftFilterInclude with `Type.**` keeps the parent and all nested members")
  func includeTypeRecursive() throws {
    // `Tank.**` is a type-name pattern; via the trailing-`**` rule it matches
    // both `Tank` itself and any nested type underneath
    let st = try makeTranslator(include: ["Tank.**"])
    #expect(st.importedTypes["Tank"] != nil)
    #expect(st.importedTypes["Tank.Fish"] != nil)
    #expect(st.importedTypes["Tank.Internal"] != nil)
    #expect(st.importedTypes["FishTank"] == nil)
  }

  @Test("file-path-only filter does not interfere with nested-type extraction")
  func filePathOnlyKeepsNested() throws {
    // A file-path-only filter must not accidentally gate type-level filtering;
    // every nested type in the included file should still be extracted
    let st = try makeTranslator(include: ["**/Fake.swift", "Fake.swift"])
    #expect(st.importedTypes["Tank"] != nil)
    #expect(st.importedTypes["Tank.Fish"] != nil)
    #expect(st.importedTypes["Tank.Internal"] != nil)
    #expect(st.importedTypes["FishTank"] != nil)
  }
}
