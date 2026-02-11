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

import CSwiftJavaJNI
import Foundation
import SwiftJava

public typealias SwiftJavaFoundationURL = Foundation.URL

extension SwiftJavaFoundationURL {
  public static func fromJava(_ url: URL) throws -> SwiftJavaFoundationURL {
    guard let converted = SwiftJavaFoundationURL(string: try url.toURI().toString()) else {
      throw SwiftJavaConversionError("Failed to convert \(URL.self) to \(SwiftJavaFoundationURL.self)")
    }
    return converted
  }
}

extension URL {
  public static func fromSwift(_ url: SwiftJavaFoundationURL) throws -> URL {
    try URL(url.absoluteString)
  }
}
