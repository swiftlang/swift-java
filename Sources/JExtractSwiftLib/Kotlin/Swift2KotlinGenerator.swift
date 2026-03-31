//
//  Swift2KotlinGenerator.swift
//  swift-java
//
//  Created by Tanish Azad on 31/03/26.
//

import CodePrinting
import SwiftJavaConfigurationShared
import SwiftJavaJNICore
import SwiftSyntax
import SwiftSyntaxBuilder

import struct Foundation.URL

package class Swift2KotlinGenerator: Swift2JavaGenerator {
  let log: Logger
  let config: Configuration
  let analysis: AnalysisResult
  let swiftModuleName: String
  let kotlinPackage: String
  let swiftOutputDirectory: String
  let kotlinOutputDirectory: String
  let lookupContext: SwiftTypeLookupContext

  var kotlinPackagePath: String {
    kotlinPackage.replacingOccurrences(of: ".", with: "/")
  }

  var thunkNameRegistry: ThunkNameRegistry = ThunkNameRegistry()
  
  /// Cached Java translation result. 'nil' indicates failed translation.
  var translatedDecls: [ImportedFunc: TranslatedFunctionDecl?] = [:]

  /// Duplicate identifier tracking for the current batch of methods being generated.
  var currentJavaIdentifiers: JavaIdentifierFactory = JavaIdentifierFactory()

  /// Because we need to write empty files for SwiftPM, keep track which files we didn't write yet,
  /// and write an empty file for those.
  ///
  /// Since Swift files in SwiftPM builds needs to be unique, we use this fact to flatten paths into plain names here.
  /// For uniqueness checking "did we write this file already", just checking the name should be sufficient.
  var expectedOutputSwiftFileNames: Set<String>

  package init(
    config: Configuration,
    translator: Swift2JavaTranslator,
    kotlinPackage: String,
    swiftOutputDirectory: String,
    kotlinOutputDirectory: String
  ) {
    self.log = Logger(label: "kotlin-generator", logLevel: translator.log.logLevel)
    self.config = config
    self.analysis = translator.result
    self.swiftModuleName = translator.swiftModuleName
    self.kotlinPackage = kotlinPackage
    self.swiftOutputDirectory = swiftOutputDirectory
    self.kotlinOutputDirectory = kotlinOutputDirectory
    self.lookupContext = translator.lookupContext

    // If we are forced to write empty files, construct the expected outputs.
    // It is sufficient to use file names only, since SwiftPM requires names to be unique within a module anyway.
    if translator.config.writeEmptyFiles ?? false {
      self.expectedOutputSwiftFileNames = Set(
        translator.inputs.compactMap { (input) -> String? in
          guard let fileName = input.path.split(separator: PATH_SEPARATOR).last else {
            return nil
          }
          guard fileName.hasSuffix(".swift") else {
            return nil
          }
          return String(fileName.replacing(".swift", with: "+SwiftKotlin.swift"))
        }
      )
      self.expectedOutputSwiftFileNames.insert("\(translator.swiftModuleName)Module+SwiftKotlin.swift")
      self.expectedOutputSwiftFileNames.insert("Foundation+SwiftKotlin.swift")
    } else {
      self.expectedOutputSwiftFileNames = []
    }
  }

  func generate() throws {
    // try writeSwiftThunkSources()
    // log.info("Generated Swift sources (module: '\(self.swiftModuleName)') in: \(swiftOutputDirectory)/")

    try writeExportedJavaSources()
    log.info("Generated Kotlin sources (package: '\(kotlinPackage)') in: \(kotlinOutputDirectory)/")

    // try writeSwiftExpectedEmptySources()
  }
}

extension Swift2KotlinGenerator {
  package func writeExportedJavaSources() throws {
    var printer = CodePrinter()
    try writeExportedJavaSources(printer: &printer)
  }

  /// Every imported public type becomes a public class in its own file in Java.
  package func writeExportedJavaSources(printer: inout CodePrinter) throws {
    for (_, ty) in analysis.importedTypes.sorted(by: { (lhs, rhs) in lhs.key < rhs.key }) {
      let filename = "\(ty.swiftNominal.name).kt"
      log.debug("Printing contents: \(filename)")
      printImportedNominal(&printer, ty)

      if let outputFile = try printer.writeContents(
        outputDirectory: kotlinOutputDirectory,
        javaPackagePath: kotlinPackagePath,
        filename: filename
      ) {
        log.info("Generated: \((ty.swiftNominal.name.bold + ".kt").bold) (at \(outputFile.absoluteString))")
      }
    }

    do {
      let filename = "\(self.swiftModuleName).kt"
      log.debug("Printing contents: \(filename)")
      printModule(&printer)

      if let outputFile = try printer.writeContents(
        outputDirectory: kotlinOutputDirectory,
        javaPackagePath: kotlinPackagePath,
        filename: filename
      ) {
        log.info("Generated: \((self.swiftModuleName + ".kt").bold) (at \(outputFile.absoluteString))")
      }
    }
  }
}

// ==== ---------------------------------------------------------------------------------------------------------------
// MARK: Kotlin/text printing

extension Swift2KotlinGenerator {
  /// Render the Java file contents for an imported Swift module.
  ///
  /// This includes any Swift global functions in that module, and some general type information and helpers.
  func printModule(_ printer: inout CodePrinter) {
    printHeader(&printer)
    printPackage(&printer)

//    self.currentJavaIdentifiers = JavaIdentifierFactory(
//      self.analysis.importedGlobalFuncs + self.analysis.importedGlobalVariables
//    )
//
//    printModuleClass(&printer) { printer in
//      for decl in analysis.importedGlobalVariables {
//        self.log.trace("Print imported decl: \(decl)")
//        printKotlinBindingPlaceholder(&printer, decl)
//      }
//
//      for decl in analysis.importedGlobalFuncs {
//        self.log.trace("Print imported decl: \(decl)")
//        printKotlinBindingPlaceholder(&printer, decl)
//      }
//    }
  }

  func printImportedNominal(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printHeader(&printer)
    printPackage(&printer)

//    self.currentJavaIdentifiers = JavaIdentifierFactory(
//      decl.initializers + decl.variables + decl.methods
//    )
//
//    printNominal(&printer, decl) { printer in
//      // Initializers
//      for initDecl in decl.initializers {
//        printKotlinBindingPlaceholder(&printer, initDecl)
//      }
//
//      // Properties
//      for accessorDecl in decl.variables {
//        printKotlinBindingPlaceholder(&printer, accessorDecl)
//      }
//
//      // Methods
//      for funcDecl in decl.methods {
//        printKotlinBindingPlaceholder(&printer, funcDecl)
//      }
//
//      // Helper methods and default implementations
//      printToStringMethod(&printer, decl)
//    }
  }

  func printHeader(_ printer: inout CodePrinter) {
    printer.print(
      """
      // Generated by jextract-swift
      // Swift module: \(swiftModuleName)

      """
    )
  }

  func printPackage(_ printer: inout CodePrinter) {
    printer.print(
      """
      package \(kotlinPackage)

      """
    )
  }

  func printNominal(
    _ printer: inout CodePrinter,
    _ decl: ImportedNominalType,
    body: (inout CodePrinter) -> Void
  ) {
    printer.printBraceBlock(
      "class \(decl.swiftNominal.name) private constructor()"
    ) { printer in
      body(&printer)
    }
  }

  func printModuleClass(_ printer: inout CodePrinter, body: (inout CodePrinter) -> Void) {
    printer.printBraceBlock("class \(swiftModuleName) private constructor()") { printer in
      body(&printer)
    }
  }

  func printToStringMethod(
    _ printer: inout CodePrinter,
    _ decl: ImportedNominalType
  ) {
    printer.print(
      """
      override fun toString(): String {
          TODO("Not implemented")
      }
      """
    )
  }

}
