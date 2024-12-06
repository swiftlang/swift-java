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

package org.swift.javakit.annotations;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

/**
 * Since some public methods may not appear as used in Java source code, but are used by Swift,
 * we can use this source annotation to mark such entry points to not accidentally remove them with
 * "safe delete" refactorings in Java IDEs which would be unaware of the usages from Swift.
 */
@SuppressWarnings("unused") // used from Swift
@Retention(RetentionPolicy.SOURCE)
public @interface UsedFromSwift {
}
