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

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember

/**
 * Remembers a Swift `@Observable` model and wires its change notifications into
 * the current composition.
 *
 * This is the single supported entry point for observing a Swift model from
 * Compose. The [factory] is invoked once (via [remember]) to create the model,
 * which is then kept for the lifetime of the composition. A [DisposableEffect]
 * subscribes to the model's Swift-side changes when the composable enters the
 * composition ([SwiftObservable.retainObserver]) and unsubscribes when it leaves
 * ([SwiftObservable.releaseObserver]).
 *
 * While the subscription is active, reading an observed property on the returned
 * model inside a composable records that read with Compose's snapshot system, so
 * a change to that property on the Swift side triggers recomposition of only the
 * composables that read it.
 *
 * To observe a nested observable, call [rememberSwiftObservable] again for the
 * child, e.g. `val address = rememberSwiftObservable { profile.address }`.
 *
 * **Threading:** this must be called from a Compose composition, which runs on
 * the main thread. Observation is only supported on the main thread; do not
 * drive [SwiftObservable.retainObserver]/[SwiftObservable.releaseObserver]
 * manually from another thread.
 *
 * @param factory creates the model; called exactly once for the composition.
 * @return the remembered model, observed for the lifetime of the composition.
 */
@Composable
fun <T> rememberSwiftObservable(factory: () -> T): T where T : SwiftObservable {
    val model = remember { factory() }
    DisposableEffect(model) {
        model.retainObserver()
        onDispose { model.releaseObserver() }
    }
    return model
}
