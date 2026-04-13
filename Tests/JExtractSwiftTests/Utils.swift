//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

func withTemporaryFile(
  fileName: String = "tmp_\(UUID().uuidString)",
  extension: String,
  contents: String = "",
  in tempDirectory: URL = FileManager.default.temporaryDirectory,
  _ perform: (URL) throws -> Void
) throws {
  let tempFileName = "\(fileName).\(`extension`)"
  let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)

  try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  try contents.write(to: tempFileURL, atomically: true, encoding: .utf8)
  defer {
    try? FileManager.default.removeItem(at: tempFileURL)
  }
  try perform(tempFileURL)
}
