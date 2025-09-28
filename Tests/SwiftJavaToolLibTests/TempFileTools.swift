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

import Foundation

/// Example demonstrating how to create a temporary file using Swift Foundation APIs
public class TempFile {
    
    public static func create(
        suffix: String,
        _ contents: String = "",
        in tempDirectory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let tempFileName = "tmp_\(UUID().uuidString).\(suffix)"
        let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)
        
        try contents.write(to: tempFileURL, atomically: true, encoding: .utf8)
        
        return tempFileURL
    }
    public static func delete(at fileURL: URL) throws {
        try FileManager.default.removeItem(at: fileURL)
    }
}