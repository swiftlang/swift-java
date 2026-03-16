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

import Foundation
import SwiftJava
import SwiftJavaJNICore

extension JavaURL {
  @JavaMethod
  public func toURI() throws -> URI!
}

extension URL {
  public static func fromJava(_ url: JavaURL) throws -> URL {
    guard let converted = URL(string: try url.toURI().toString()) else {
      throw SwiftJavaConversionError("Failed to convert \(JavaURL.self) to \(URL.self)")
    }
    return converted
  }
}

extension JavaURL {
  public static func fromSwift(_ url: URL) throws -> JavaURL {
    try JavaURL(url.absoluteString)
  }
}
