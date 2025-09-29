//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
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
import SwiftJavaShared
import _Subprocess
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

class WrapJavaTests: XCTestCase {

  func testWrapJavaFromCompiledJavaSource() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class ExampleSimpleClass {}
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.ExampleSimpleClass")
        open class ExampleSimpleClass: JavaObject {
        """
      ]
    )
  }

  /*
  /Users/ktoso/code/voldemort-swift-java/.build/plugins/outputs/voldemort-swift-java/VoldemortSwiftJava/destination/SwiftJavaPlugin/generated/CompressingStore.swift:6:30: error: reference to generic type 'AbstractStore' requires arguments in <...>
 4 |
 5 | @JavaClass("voldemort.store.compress.CompressingStore")
 6 | open class CompressingStore: AbstractStore {
   |                              `- error: reference to generic type 'AbstractStore' requires arguments in <...>
 7 |   @JavaMethod
 8 |   open override func getCapability(_ arg0: StoreCapabilityType?) -> JavaObject!

/Users/ktoso/code/voldemort-swift-java/.build/plugins/outputs/voldemort-swift-java/VoldemortSwiftJava/destination/SwiftJavaPlugin/generated/AbstractStore.swift:6:12: note: generic type 'AbstractStore' declared here
 4 |
 5 | @JavaClass("voldemort.store.AbstractStore", implements: Store<JavaObject, JavaObject, JavaObject>.self)
 6 | open class AbstractStore<K: AnyJavaObject, V: AnyJavaObject, T: AnyJavaObject>: JavaObject {
   |            `- note: generic type 'AbstractStore' declared here
 7 |   @JavaMethod
 8 |   @_nonoverride public convenience init(_ arg0: String, environment: JNIEnvironment? = nil)
  */
  func testGenericSuperclass() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class ByteArray {}
      class CompressingStore extends AbstractStore<ByteArray, byte[], byte[]> {}
      abstract class AbstractStore<K, V, T> {} // implements Store<K, V, T> {}
      // interface Store<K, V, T> {}

      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ByteArray",
        // TODO: what if we visit in other order, does the wrap-java handle it
        // "com.example.Store",
        "com.example.AbstractStore",
        "com.example.CompressingStore",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.ByteArray")
        open class ByteArray: JavaObject {
        """,
        """
        @JavaInterface("com.example.Store")
        public struct Store<K: AnyJavaObject, V: AnyJavaObject, T: AnyJavaObject> {
        """,
        """
        @JavaClass("com.example.CompressingStore")
        open class CompressingStore: AbstractStore {
        """
      ]
    )
  }
}

fileprivate func createTemporaryDirectory(in directory: URL) throws -> URL {
  let uuid = UUID().uuidString
  let resolverDirectoryURL = directory.appendingPathComponent("swift-java-testing-\(uuid)")

  try FileManager.default.createDirectory(at: resolverDirectoryURL, withIntermediateDirectories: true, attributes: nil)

  return resolverDirectoryURL
}

/// Returns the directory that should be added to the classpath of the JVM to analyze the sources.
func compileJava(_ sourceText: String) async throws -> URL {
  let sourceFile = try TempFile.create(suffix: "java", sourceText)
  
  let classesDirectory = try createTemporaryDirectory(in: FileManager.default.temporaryDirectory)
  
  let javacProcess = try await _Subprocess.run(
    .path("/usr/bin/javac"),
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

/// Translate a Java class and assert that the translated output contains
/// each of the expected "chunks" of text.
func assertWrapJavaOutput(
  javaClassNames: [String],
  classpath: [URL],
  expectedChunks: [String],
  function: String = #function,
  file: StaticString = #filePath,
  line: UInt = #line
) throws {
  let jvm = try JavaVirtualMachine.shared(
    classpath: classpath.map(\.path),
    replace: false
  )
  
  let environment = try jvm.environment()
  let translator = JavaTranslator(
    swiftModuleName: "SwiftModule",
    environment: environment,
    translateAsClass: true)

  let classLoader = try! JavaClass<JavaClassLoader>(environment: environment)
    .getSystemClassLoader()!


  // FIXME: deduplicate this
  translator.startNewFile()

  var swiftCompleteOutputText = ""

  var javaClasses: [JavaClass<JavaObject>] = []
  for javaClassName in javaClassNames {
    guard let javaClass = try classLoader.loadClass(javaClassName) else {
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
    if swiftCompleteOutputText.contains(expectedChunk) {
      continue
    }

    XCTFail("Expected chunk: \n" +
    "\(expectedChunk.yellow)" + 
    "\n" + 
    "not found in:\n" +
    "\(swiftCompleteOutputText)",
     file: file, line: line)
  }

  print(swiftCompleteOutputText)
}