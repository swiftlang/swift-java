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

@_spi(Testing) import SwiftJava
import SwiftJavaToolLib
import JavaUtilJar
import JavaNet
import SwiftJavaShared
import SwiftJavaConfigurationShared
import _Subprocess
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43
import Foundation

fileprivate func createTemporaryDirectory(in directory: Foundation.URL) throws -> Foundation.URL {
  let uuid = UUID().uuidString
  let resolverDirectoryURL = directory.appendingPathComponent("swift-java-testing-\(uuid)")

  try FileManager.default.createDirectory(at: resolverDirectoryURL, withIntermediateDirectories: true, attributes: nil)

  return resolverDirectoryURL
}

/// Returns the directory that should be added to the classpath of the JVM to analyze the sources.
func compileJava(_ sourceText: String) async throws -> Foundation.URL {
  let sourceFile = try TempFile.create(suffix: "java", sourceText)
  
  let classesDirectory = try createTemporaryDirectory(in: FileManager.default.temporaryDirectory)
  
  let javacProcess = try await _Subprocess.run(
    .path(.init("\(javaHome)" + "/bin/javac")),
    arguments: [
      "-d", classesDirectory.path, // output directory for .class files
      sourceFile.path
    ],
    output: .string(limit: Int.max, encoding: UTF8.self),
    error: .string(limit: Int.max, encoding: UTF8.self)
  )
  
  // Check if compilation was successful
  guard javacProcess.terminationStatus.isSuccess else {
    let outString = javacProcess.standardOutput ?? ""
    let errString = javacProcess.standardError ?? ""
    fatalError("javac '\(sourceFile)' failed (\(javacProcess.terminationStatus));\n" + 
    "OUT: \(outString)\n" + 
    "ERROR: \(errString)")
  }
  
  print("Compiled java sources to: \(classesDirectory)")
  return classesDirectory
}

func withJavaTranslator(
  javaClassNames:  [String],
  classpath: [Foundation.URL],
  body: (JavaTranslator) throws -> (),
  function: String = #function,
  file: StaticString = #filePath,
  line: UInt = #line
) throws {
  print("New withJavaTranslator, for classpath: \(classpath)")
  let jvm = try JavaVirtualMachine.shared(
    classpath: classpath.map(\.path),
    replace: true
  )
  
  var config = Configuration()
  config.minimumInputAccessLevelMode = .package

  let environment = try jvm.environment()
  let translator = JavaTranslator(
    config: config,
    swiftModuleName: "SwiftModule",
    environment: environment,
    translateAsClass: true)

  try body(translator)
}

/// Translate a Java class and assert that the translated output contains
/// each of the expected "chunks" of text.
func assertWrapJavaOutput(
  javaClassNames: [String],
  classpath: [Foundation.URL],
  expectedChunks: [String],
  function: String = #function,
  file: StaticString = #filePath,
  line: UInt = #line
) throws {
  let jvm = try JavaVirtualMachine.shared(
    //classpath: classpath.map(\.path),
    replace: false
  )
  // Do NOT destroy the jvm here, because the JavaClasses will need to deinit,
  // and do so while the env is still valid...
  
  var config = Configuration()
  config.minimumInputAccessLevelMode = .package

  let environment = try jvm.environment()
  let translator = JavaTranslator(
    config: config,
    swiftModuleName: "SwiftModule",
    environment: environment,
    translateAsClass: true)

  let classpathJavaURLs = classpath.map({ try! URL.init("\($0)/") }) // we MUST have a trailing slash for JVM to consider it a search directory
  let classLoader = URLClassLoader(classpathJavaURLs, environment: environment)

  // FIXME: deduplicate this
  translator.startNewFile()

  var swiftCompleteOutputText = ""

  var javaClasses: [JavaClass<JavaObject>] = []
  for javaClassName in javaClassNames {
    guard let javaClass = try! classLoader.loadClass(javaClassName) else {
      fatalError("Could not load Java class '\(javaClassName)' in test \(function) @ \(file):\(line)!")
    }
    javaClasses.append(javaClass)

    // FIXME: deduplicate this with SwiftJava.WrapJavaCommand.runCommand !!!
    // TODO: especially because nested classes
    // WrapJavaCommand().<TODO>

    let swiftUnqualifiedName = javaClassName.javaClassNameToCanonicalName
            .defaultSwiftNameForJavaClass
    translator.translatedClasses[javaClassName] =
      .init(module: nil, name: swiftUnqualifiedName)

    try translator.validateClassConfiguration() 

    let swiftClassDecls = try translator.translateClass(javaClass)
    let importDecls = translator.getImportDecls()

  let swiftFileText = 
    """
    // ---------------------------------------------------------------------------
    // Auto-generated by Java-to-Swift wrapper generator.
    \(importDecls.map { $0.description }.joined())
    \(swiftClassDecls.map { $0.description }.joined(separator: "\n"))
    \n
    """
    swiftCompleteOutputText += swiftFileText
  }

  for expectedChunk in expectedChunks {
    // We make the matching in-sensitive to whitespace:
    let checkAgainstText = swiftCompleteOutputText.replacing(" ", with: "")
    let checkAgainstExpectedChunk = expectedChunk.replacing(" ", with: "")

let failureMessage = "Expected chunk: \n" +
      "\(expectedChunk.yellow)" + 
      "\n" + 
      "not found in:\n" +
      "\(swiftCompleteOutputText)"
    XCTAssertTrue(checkAgainstText.contains(checkAgainstExpectedChunk), 
      "\(failureMessage)")
  }
}