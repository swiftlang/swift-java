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
 * Callback invoked from Swift when an observed property of a bridged
 * `@Observable` model changes.
 *
 * The generated Java binding of an observable type implements this interface and
 * passes itself to the Swift side when observation starts. Swift then calls
 * [onPropertyChanged] for each subsequent change, identifying the property by
 * the stable id assigned to it during code generation.
 *
 * **Threading:** invocations are delivered on the main thread.
 */
fun interface SwiftObserverCallback {
    /**
     * Called when the observed property identified by [propertyId] changes.
     *
     * @param propertyId the generator-assigned id of the changed property; the
     *   binding maps it back to the matching [TrackingToken] to invalidate.
     */
    fun onPropertyChanged(propertyId: Int)
}