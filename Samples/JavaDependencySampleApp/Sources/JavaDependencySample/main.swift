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

import SwiftJava
import JavaUtilFunction
import JavaIO
import SwiftJavaConfigurationShared
import Foundation

// Import the commons-csv library wrapper:
import JavaCommonsCSV

print("")
print("")
print("-----------------------------------------------------------------------")
print("Start Sample app...")

// TODO: locating the classpath is more complex, need to account for dependencies of our module
let swiftJavaClasspath = findSwiftJavaClasspaths() // scans for .classpath files

// 1) Start a JVM with appropriate classpath
let jvm = try JavaVirtualMachine.shared(classpath: swiftJavaClasspath)

// 2) Get the FilenameUtils Java class so we can call the static methods on it
let FilenameUtilsClass = try JavaClass<FilenameUtils>()

// Some silly sample path we want to work with:
let path = "/example/path/executable.exe"
print("Path = \(path)")

let ext = try! FilenameUtilsClass.getExtension(path)
print("org.apache.commons.io.FilenameUtils.getExtension = \(ext)")
precondition(ext == "exe")

let CSVFormatClass = try JavaClass<CSVFormat>()

let reader = StringReader("hello,example")
for record in try CSVFormatClass.RFC4180.parse(reader)!.getRecords()! {
  for field in record.toList()! {
    print("Field: \(field)")
  }
}

print("Done.")
