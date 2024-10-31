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

import JavaRuntime

#if canImport(Android)
typealias JNINativeInterface_ = JNINativeInterface
#endif

extension UnsafeMutablePointer<JNIEnv?> {
  var interface: JNINativeInterface_ { self.pointee!.pointee }
}
