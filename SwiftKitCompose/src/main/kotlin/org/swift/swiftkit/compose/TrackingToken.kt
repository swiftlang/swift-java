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

package org.swift.swiftkit.compose

import androidx.compose.runtime.mutableIntStateOf

/**
 * Bridges a Swift `@Observable` object's change notifications into the Compose
 * snapshot system.
 *
 * Holds no value of its own — only a snapshot-tracked version counter. A getter
 * on the bridged Java type calls [observe] so the read is recorded in the current
 * Compose snapshot; when Swift reports a change
 * the bridge calls [invalidate] to bump the counter and trigger
 * recomposition of any composable that read it.
 */
class TrackingToken {
    private val version = mutableIntStateOf(0)

    fun observe() {
        version.intValue
    }

    fun invalidate() {
        version.intValue++
    }
}
