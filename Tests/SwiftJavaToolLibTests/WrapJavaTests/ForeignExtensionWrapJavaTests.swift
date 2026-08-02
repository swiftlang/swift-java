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

import Foundation
import JavaNet
@_spi(Testing) import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import XCTest

@testable import SwiftJavaToolLib

final class ForeignExtensionWrapJavaTests: XCTestCase {


  func test_wrapJava_generatesExtensionOfForeignJavaClass() async throws {
    let classpathURL = try await compileJava("class Foo {}")

    let jvm = try JavaVirtualMachine.shared(replace: false)
    let environment = try jvm.environment()

    var config = Configuration()
    config.minimumInputAccessLevelMode = .package

    let currentModule = "JavaLangReflect"
    let translator = JavaTranslator(
      config: config,
      swiftModuleName: currentModule,
      environment: environment,
      translateAsClass: true
    )

    translator.translatedClasses["java.lang.Class"] = .init(module: "SwiftJava", name: "JavaClass")
    translator.translatedClasses["java.lang.String"] = .init(module: "SwiftJava", name: "String")
    translator.translatedClasses["java.lang.reflect.Method"] = .init(module: currentModule, name: "Method")
    translator.translatedClasses["java.lang.reflect.Field"] = .init(module: currentModule, name: "Field")

    translator.startNewFile()

    let classLoader = URLClassLoader(
      [try! URI("\(classpathURL)/").toURL()],
      environment: environment
    )
    let loaded = try classLoader.loadClass("java.lang.Class")
    let javaLangClass = try XCTUnwrap(loaded, "Could not load java.lang.Class")

    let decls = try translator.translateClassAsForeignExtension(javaLangClass)
    let output = decls.map { $0.description }.joined(separator: "\n")
    let compact = output.replacing(" ", with: "")

    XCTAssertTrue(
      compact.contains("extensionJavaClass{"),
      "Expected an `extension JavaClass { ... }`, got:\n\(output)"
    )

    XCTAssertTrue(
      compact.contains("getDeclaredMethods()->[Method?]")
        || compact.contains("getDeclaredMethods()throws->[Method?]"),
      "Expected `getDeclaredMethods()` returning [Method?], got:\n\(output)"
    )
    XCTAssertTrue(
      compact.contains("getFields()->[Field?]")
        || compact.contains("getFields()throws->[Field?]"),
      "Expected `getFields()` returning [Field?], got:\n\(output)"
    )
    XCTAssertFalse(
      compact.contains("openfuncgetDeclaredMethods"),
      "Extension members must not be `open`:\n\(output)"
    )
    XCTAssertFalse(
      compact.contains("funcgetName("),
      "Did not expect getName() (references only String, a foreign-module type):\n\(output)"
    )
  }


  func test_wrapJava_foreignExtensionOnlyIncludesCurrentModuleMembers() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class Color {}

      class Palette {
        public Color primary() { return null; }
        public Color[] all() { return null; }
        public String describe() { return ""; }
        public Palette copy() { return null; }
      }
      """
    )

    let jvm = try JavaVirtualMachine.shared(replace: false)
    let environment = try jvm.environment()

    var config = Configuration()
    config.minimumInputAccessLevelMode = .package

    let currentModule = "MyColors"
    let translator = JavaTranslator(
      config: config,
      swiftModuleName: currentModule,
      environment: environment,
      translateAsClass: true
    )

    translator.translatedClasses["com.example.Palette"] = .init(module: "Upstream", name: "Palette")
    translator.translatedClasses["com.example.Color"] = .init(module: currentModule, name: "Color")
    translator.translatedClasses["java.lang.String"] = .init(module: "SwiftJava", name: "String")

    translator.startNewFile()

    let classLoader = URLClassLoader(
      [try! URI("\(classpathURL)/").toURL()],
      environment: environment
    )
    let palette = try XCTUnwrap(try classLoader.loadClass("com.example.Palette"))

    let decls = try translator.translateClassAsForeignExtension(palette)
    let output = decls.map { $0.description }.joined(separator: "\n")
    let compact = output.replacing(" ", with: "")

    XCTAssertTrue(
      compact.contains("extensionPalette{"),
      "Expected an `extension Palette { ... }`, got:\n\(output)"
    )
    XCTAssertTrue(
      compact.contains("primary()->Color!"),
      "Expected `primary() -> Color!`, got:\n\(output)"
    )
    XCTAssertTrue(
      compact.contains("all()->[Color?]"),
      "Expected `all() -> [Color?]`, got:\n\(output)"
    )
    XCTAssertFalse(
      compact.contains("funcdescribe("),
      "Did not expect describe() (returns only String, a foreign type):\n\(output)"
    )
    XCTAssertFalse(
      compact.contains("funccopy("),
      "Did not expect copy() (returns only Palette, a foreign type):\n\(output)"
    )
  }

  func test_wrapJava_foreignExtensionIncludesConstructorsAndStaticMembers() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class Color {}

      class Palette {
        public static final Color DEFAULT = null;
        public static final String NAME = "";

        public Palette(Color seed) {}
        public Palette(String name) {}

        public static Color mix(Color a, Color b) { return null; }
        public static String describe() { return ""; }
      }
      """
    )

    let jvm = try JavaVirtualMachine.shared(replace: false)
    let environment = try jvm.environment()

    var config = Configuration()
    config.minimumInputAccessLevelMode = .package

    let currentModule = "MyColors"
    let translator = JavaTranslator(
      config: config,
      swiftModuleName: currentModule,
      environment: environment,
      translateAsClass: true
    )

    translator.translatedClasses["com.example.Palette"] = .init(module: "Upstream", name: "Palette")
    translator.translatedClasses["com.example.Color"] = .init(module: currentModule, name: "Color")
    translator.translatedClasses["java.lang.String"] = .init(module: "SwiftJava", name: "String")

    translator.startNewFile()

    let classLoader = URLClassLoader(
      [try! URI("\(classpathURL)/").toURL()],
      environment: environment
    )
    let palette = try XCTUnwrap(try classLoader.loadClass("com.example.Palette"))

    let decls = try translator.translateClassAsForeignExtension(palette)
    let all = decls.map { $0.description }.joined(separator: "\n")

    XCTAssertEqual(decls.count, 2, "Expected a static and an instance extension, got:\n\(all)")

    let staticExtension = try XCTUnwrap(
      decls.first { $0.description.replacing(" ", with: "").contains("extensionJavaClass<Palette>{") },
      "Expected an `extension JavaClass<Palette> { ... }`, got:\n\(all)"
    ).description.replacing(" ", with: "")

    let instanceExtension = try XCTUnwrap(
      decls.first { $0.description.replacing(" ", with: "").contains("extensionPalette{") },
      "Expected an `extension Palette { ... }`, got:\n\(all)"
    ).description.replacing(" ", with: "")

    XCTAssertTrue(
      instanceExtension.contains("convenienceinit(_arg0:Color?"),
      "Expected a convenience init taking Color:\n\(all)"
    )
    XCTAssertFalse(
      instanceExtension.contains("init(_arg0:String"),
      "Did not expect the String constructor:\n\(all)"
    )
    XCTAssertTrue(
      staticExtension.contains("funcmix("),
      "Expected static mix(Color, Color) on JavaClass<Palette>:\n\(all)"
    )
    XCTAssertTrue(
      staticExtension.contains("varDEFAULT:Color"),
      "Expected static field DEFAULT: Color on JavaClass<Palette>:\n\(all)"
    )
    XCTAssertFalse(
      instanceExtension.contains("funcmix("),
      "Did not expect the static method on the instance extension:\n\(all)"
    )
    XCTAssertFalse(
      instanceExtension.contains("varDEFAULT"),
      "Did not expect the static field on the instance extension:\n\(all)"
    )

    XCTAssertFalse(
      staticExtension.contains("funcdescribe("),
      "Did not expect static describe():\n\(all)"
    )
    XCTAssertFalse(
      staticExtension.contains("varNAME"),
      "Did not expect static field NAME:\n\(all)"
    )
  }
}
