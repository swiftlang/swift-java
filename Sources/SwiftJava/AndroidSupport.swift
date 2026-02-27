//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public enum AndroidSupport {
  /// Performs any known name conversions
  /// for types that are desugared on specific Android versions
  public static func androidDesugarClassNameConversion(
    for fullClassName: String
  ) -> String {
    #if os(Android) && AndroidCoreLibraryDesugaring
    switch fullClassName {
    case "java.util.Optional":
      return "j$.util.Optional"

    default:
      break
    }
    #endif
    return fullClassName
  }
}
