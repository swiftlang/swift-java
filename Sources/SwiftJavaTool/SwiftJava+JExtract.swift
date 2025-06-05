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
import ArgumentParser
import SwiftJavaLib
import JavaKit
import JavaKitJar
import SwiftJavaLib
import JExtractSwiftLib
import JavaKitConfigurationShared

/// Extract Java bindings from Swift sources or interface files.
///
/// Example usage:
/// ```
/// > swift-java --input-swift Sources/SwiftyBusiness \
///              --output-swift .build/.../outputs/SwiftyBusiness \
///              --output-Java .build/.../outputs/Java
/// ```
extension SwiftJava {

  mutating func jextractSwift(
    config: Configuration
  ) throws {

  }

}
