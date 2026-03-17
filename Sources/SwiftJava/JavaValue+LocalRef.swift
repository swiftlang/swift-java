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

import SwiftJavaJNICore

extension JavaValue {
  /// Return JNI value as a local ref safe for returning from @_cdecl functions.
  ///
  /// Default: delegates to ``getJNIValue(in:)``.
  /// Overridden for `Optional<AnyJavaObject>` to call `NewLocalRef`,
  /// ensuring the reference survives ARC destruction of the temporary
  /// `JavaObject` in the function epilog.
  public func getJNILocalRefValue(in environment: JNIEnvironment) -> JNIType {
    getJNIValue(in: environment)
  }
}
