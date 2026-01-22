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
import CSwiftJavaJNI

extension Throwable { 
  // TODO: We cannot have this method in SwiftJava module unless we also lower PrintStream from JavaIO into SwiftJava

  /// Prints this throwable and its backtrace to the specified print stream.
  /// 
  /// ### Java method signature
  /// ```
  /// public void printStackTrace(PrintStream s)
  /// ```
  @JavaMethod
  func fillInStackTrace(_ writer: PrintWriter?)
}