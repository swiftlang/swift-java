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

// Mirrors `Optionals.swift` in the JNI sample app, so that documentation can
// show one Swift example alongside its usage in both jextract modes
//
// Note that only optional *parameters* are supported in FFM mode, which is why
// this function returns a non-optional value

public func optionalLongOrZero(input: Int64?) -> Int64 {
  input ?? 0
}
