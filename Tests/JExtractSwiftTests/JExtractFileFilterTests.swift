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

@testable import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

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
  }

  // ==== -------------------------------------------------------------------
  // MARK: shouldJExtractFile tests

  @Test("No filters means everything passes")
  func noFilters() {
    var config = Configuration()
    #expect(shouldJExtractFile(relativePath: "Anything.swift", config: config))

    config.swiftFilterInclude = []
    config.swiftFilterExclude = []
    #expect(shouldJExtractFile(relativePath: "Anything.swift", config: config))
  }

  @Test("File include filter only")
  func fileIncludeOnly() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**"]

    #expect(shouldJExtractFile(relativePath: "Models/User.swift", config: config))
    #expect(shouldJExtractFile(relativePath: "Models/Sub/Deep.swift", config: config))
    #expect(!shouldJExtractFile(relativePath: "Other/Thing.swift", config: config))
  }

  @Test("File exclude filter only")
  func fileExcludeOnly() {
    var config = Configuration()
    config.swiftFilterExclude = ["Internal/*"]

    #expect(shouldJExtractFile(relativePath: "Models/User.swift", config: config))
    #expect(!shouldJExtractFile(relativePath: "Internal/Secret.swift", config: config))
  }

  @Test("File include and exclude combined")
  func fileIncludeAndExclude() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**"]
    config.swiftFilterExclude = ["Models/Internal*"]

    #expect(shouldJExtractFile(relativePath: "Models/User.swift", config: config))
    #expect(!shouldJExtractFile(relativePath: "Models/InternalHelper.swift", config: config))
    #expect(!shouldJExtractFile(relativePath: "Other/Thing.swift", config: config))
  }

  @Test("Type-name patterns are ignored by shouldJExtractFile")
  func typeNamePatternsIgnoredByFileFilter() {
    var config = Configuration()
    config.swiftFilterInclude = ["Something.Other"]

    // Type-name-only includes should not restrict file-level filtering
    #expect(shouldJExtractFile(relativePath: "Anything.swift", config: config))
  }

  // ==== -------------------------------------------------------------------
  // MARK: shouldJExtractType tests

  @Test("No filters means all types pass")
  func noFiltersAllTypesPass() {
    let config = Configuration()
    #expect(shouldJExtractType(qualifiedName: "Anything", config: config))
    #expect(shouldJExtractType(qualifiedName: "A.B.C", config: config))
  }

  @Test("Type include filter")
  func typeIncludeFilter() {
    var config = Configuration()
    config.swiftFilterInclude = ["Something.Other"]

    #expect(shouldJExtractType(qualifiedName: "Something.Other", config: config))
    #expect(!shouldJExtractType(qualifiedName: "Something.Wrong", config: config))
  }

  @Test("Type exclude filter")
  func typeExcludeFilter() {
    var config = Configuration()
    config.swiftFilterExclude = ["Something.Internal*"]

    #expect(shouldJExtractType(qualifiedName: "Something.Other", config: config))
    #expect(!shouldJExtractType(qualifiedName: "Something.InternalHelper", config: config))
  }

  @Test("File-path patterns are ignored by shouldJExtractType")
  func filePathPatternsIgnoredByTypeFilter() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**"]

    // File-path-only includes should not restrict type-level filtering
    #expect(shouldJExtractType(qualifiedName: "Anything", config: config))
  }

  @Test("Plain pattern matches both file and type")
  func plainPatternMatchesBoth() {
    var config = Configuration()
    config.swiftFilterInclude = ["MyType"]

    // Plain pattern works at file level (matched against filename segment)
    #expect(shouldJExtractFile(relativePath: "MyType.swift", config: config))
    #expect(!shouldJExtractFile(relativePath: "OtherType.swift", config: config))

    // Plain pattern works at type level
    #expect(shouldJExtractType(qualifiedName: "MyType", config: config))
    #expect(!shouldJExtractType(qualifiedName: "OtherType", config: config))
  }

  @Test("Mixed file and type patterns in same config")
  func mixedPatterns() {
    var config = Configuration()
    config.swiftFilterInclude = ["Models/**", "Something.Other"]

    // File filter applies the file-path pattern
    #expect(shouldJExtractFile(relativePath: "Models/User.swift", config: config))
    #expect(!shouldJExtractFile(relativePath: "Other/Thing.swift", config: config))

    // Type filter applies the type-name pattern
    #expect(shouldJExtractType(qualifiedName: "Something.Other", config: config))
    #expect(!shouldJExtractType(qualifiedName: "Something.Wrong", config: config))
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
}
