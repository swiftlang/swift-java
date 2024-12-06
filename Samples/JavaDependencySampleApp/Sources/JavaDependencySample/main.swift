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

import JavaKit
import JavaKitFunction
import JavaKitConfigurationShared
import Foundation

// Import the commons-csv library wrapper:
import JavaCommonsCSV

// Make sure we have the classpath loaded
// TODO: this is more complex than that, need to account for dependencies of our module
let currentDir = FileManager.default.currentDirectoryPath
let configuration = try readConfiguration(sourceDir: "\(currentDir)/Sources/JavaCommonsCSV/")

// 1) Start a JVM with apropriate classpath
let jvm = try JavaVirtualMachine.shared(classpath: configuration.classpathEntries)

// 2) Get the FilenameUtils Java class so we can call the static methods on it
let FilenameUtilsClass = try JavaClass<FilenameUtils>()

// Some silly sample path we want to work with:
let path = "/example/path/executable.exe"
print("Path = \(path)")

let ext = try! FilenameUtilsClass.getExtension(path)
print("Java FilenameUtils found extension = \(ext)")
precondition(ext == "exe")

print("Done.")
