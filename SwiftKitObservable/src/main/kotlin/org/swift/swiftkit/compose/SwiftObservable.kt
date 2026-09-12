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

/**
 * Implemented by the generated Java bindings of a Swift `@Observable` type to
 * expose its change notifications to Compose.
 *
 * You never call these methods directly — [rememberSwiftObservable]
 * drives them from a composition's lifecycle. The two methods are reference
 * counted on the binding so that a model observed by several composables
 * subscribes to the Swift side only once, and unsubscribes only when the last
 * observer goes away.
 *
 * **Threading:** observation is only supported on the main thread. Both methods
 * are expected to be called from a Compose composition (i.e. the main thread);
 * calling them from another thread is unsupported.
 */
interface SwiftObservable {
    /**
     * Begins observing the Swift model if it is not already being observed.
     */
    fun retainObserver()

    /**
     * Stops observing the Swift model once the last observer goes away.
     */
    fun releaseObserver()
}