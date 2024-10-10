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

import ArgumentParser
import Foundation
import JavaKit
import JavaKitJar
import JavaKitNetwork
import JavaKitReflection
import JavaKitVM
import SwiftSyntax
import SwiftSyntaxBuilder

/// Global instance of the Java virtual machine that we keep alive forever.
var javaVirtualMachine: JavaVirtualMachine? = nil

/// Command-line utility to drive the export of Java classes into Swift types.
@main
struct JavaToSwift: ParsableCommand {
  static var _commandName: String { "Java2Swift" }

  @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
  var moduleName: String

  @Argument(
    help:
      "The Java classes to translate into Swift written with their canonical names (e.g., java.lang.Object). If the Swift name of the type should be different from simple name of the type, it can appended to the class name with '=<swift name>'."
  )
  var classes: [String] = []

  @Option(
    help:
      "The Java-to-Swift module manifest files for any Swift module containing Swift types created to wrap Java classes."
  )
  var manifests: [String] = []

  @Option(
    help:
      "The Jar file from which the set of class names should be loaded, if the classes weren't explicitly listed."
  )
  var jarFile: String? = nil

  @Option(
    name: [.customLong("cp"), .customLong("classpath")],
    help: "Class search path of directories and zip/jar files from which Java classes can be loaded."
  )
  var classpath: [String] = []

  @Option(name: .shortAndLong, help: "The directory in which to output the generated Swift files and manifest.")
  var outputDirectory: String = "."

  mutating func run() throws {
    var vmOptions: [String] = []
    let classpath = classPathWithJarFile
    if !classpath.isEmpty {
      vmOptions.append("-cp")
      vmOptions.append(contentsOf: classpath)
    }

    let jvm = try JavaVirtualMachine(vmOptions: vmOptions)
    javaVirtualMachine = jvm

    try run(environment: jvm.environment)
  }

  mutating func run(environment: JNIEnvironment) throws {
    let translator = JavaTranslator(
      swiftModuleName: moduleName,
      environment: environment
    )

    // Load all of the translation manifests this depends on.
    for manifest in manifests {
      try translator.loadTranslationManifest(from: URL(filePath: manifest))
    }

    if jarFile == nil && classes.isEmpty {
      throw JavaToSwiftError.noClasses
    }

    // If we have a Jar file but no classes were listed, find all of the
    // classes in the Jar file.
    if let jarFileName = jarFile, classes.isEmpty {
      let jarFile = try JarFile(jarFileName, false, environment: environment)
      classes = jarFile.entries()!.compactMap { (entry) -> String? in
        guard entry.getName().hasSuffix(".class") else {
          return nil
        }

        // If any of the segments of the Java name start with a number, it's a
        // local class that cannot be mapped into Swift.
        for segment in entry.getName().split(separator: "$") {
          if segment.starts(with: /\d/) {
            return nil
          }
        }

        return String(entry.getName().replacing("/", with: ".")
          .dropLast(".class".count))
      }
    }

    // Load all of the requested classes.
    let classLoader = URLClassLoader(
      try classPathWithJarFile.map { try URL("file://\($0)", environment: environment) },
      environment: environment
    )
    var javaClasses: [JavaClass<JavaObject>] = []
    for javaClassNameOpt in self.classes {
      // Determine the Java class name and its resulting Swift name.
      let javaClassName: String
      let swiftName: String
      if let equalLoc = javaClassNameOpt.firstIndex(of: "=") {
        let afterEqual = javaClassNameOpt.index(after: equalLoc)
        javaClassName = String(javaClassNameOpt[..<equalLoc])
        swiftName = String(javaClassNameOpt[afterEqual...])
      } else {
        if let dotLoc = javaClassNameOpt.lastIndex(of: ".") {
          let afterDot = javaClassNameOpt.index(after: dotLoc)
          swiftName = String(javaClassNameOpt[afterDot...])
        } else {
          swiftName = javaClassNameOpt
        }

        javaClassName = javaClassNameOpt
      }

      guard let javaClass = try classLoader.loadClass(javaClassName) else {
        print("warning: could not find Java class '\(javaClassName)'")
        continue
      }

      javaClasses.append(javaClass)

      // Replace any $'s within the Java class name (which separate nested
      // classes) with .'s (which represent nesting in Swift).
      let translatedSwiftName = swiftName.replacing("$", with: ".")

      // Note that we will be translating this Java class, so it is a known class.
      translator.translatedClasses[javaClassName] = (translatedSwiftName, nil, true)
    }

    // Translate all of the Java classes into Swift classes.
    for javaClass in javaClasses {
      translator.startNewFile()
      let swiftClassDecls = translator.translateClass(javaClass)
      let importDecls = translator.getImportDecls()

      let swiftFileText = """
        // Auto-generated by Java-to-Swift wrapper generator.
        \(importDecls.map { $0.description }.joined())
        \(swiftClassDecls.map { $0.description }.joined(separator: "\n"))

        """

      let swiftFileName = try! translator.getSwiftTypeName(javaClass).swiftName.replacing(".", with: "+") + ".swift"
      try writeContents(
        swiftFileText,
        to: swiftFileName,
        description: "Java class '\(javaClass.getCanonicalName())' translation"
      )
    }

    // Translation manifest.
    let manifestFileName = "\(moduleName).swift2java"
    let manifestContents = try translator.encodeTranslationManifest()
    try writeContents(manifestContents, to: manifestFileName, description: "translation manifest")
  }

  /// Return the class path augmented with the Jar file, if there is one.
  var classPathWithJarFile: [String] {
    guard let jarFile else { return classpath }

    return [jarFile] + classpath
  }

  func writeContents(_ contents: String, to filename: String, description: String) throws {
    if outputDirectory == "-" {
      print("// \(filename) - \(description)")
      print(contents)
      return
    }

    print("Writing \(description) to '\(filename)'...", terminator: "")
    try contents.write(
      to: Foundation.URL(filePath: outputDirectory).appending(path: filename),
      atomically: true,
      encoding: .utf8
    )
    print(" done.")
  }
}

enum JavaToSwiftError: Error {
  case noClasses
}

extension JavaToSwiftError: CustomStringConvertible {
  var description: String {
    switch self {
    case .noClasses:
      "no classes to translate: either list Java classes or provide a Jar file"
    }
  }
}
