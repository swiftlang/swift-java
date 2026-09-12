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

package com.example.swift.compose

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.swift.swiftkit.compose.rememberSwiftObservable

/**
 * Verifies that properties which should NOT be observed don't trigger
 * recomposition:
 *
 * - `appName` (`static let`) and `launchCount` (`static var`) are type-level.
 * - `createdLabel` (`let`) is immutable.
 * - `hiddenCounter` (`@ObservationIgnored var`) opts out of tracking.
 *
 * Tapping "Bump hidden" mutates `hiddenCounter` in Swift, but the UI should
 * NOT update (its read isn't tracked). "Reveal hidden" copies that value into
 * the observed `visibleCounter`, forcing a legitimate notification — at which
 * point the previously-hidden value finally shows up.
 */
@Composable
fun EdgeCasesScreen() {
    val model = rememberSwiftObservable { EdgeCasesModel.init() }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text("Not observed", style = MaterialTheme.typography.titleSmall)
            Text("appName (static let): ${EdgeCasesModel.getAppName()}")
            Text("launchCount (static var): ${EdgeCasesModel.getLaunchCount()}")
            Text("createdLabel (let): ${model.createdLabel}")
            Text("hiddenCounter (@ObservationIgnored): ${model.hiddenCounter}")
        }
    }

    HorizontalDivider()

    Text(
        text = "Observed",
        style = MaterialTheme.typography.titleSmall,
    )
    Text(
        text = "visibleCounter: ${model.visibleCounter}",
        style = MaterialTheme.typography.headlineSmall,
    )

    OutlinedButton(onClick = { model.bumpHidden() }, modifier = Modifier.fillMaxWidth()) {
        Text("Bump hidden  (no UI update expected)")
    }
    Button(onClick = { model.bumpVisible() }, modifier = Modifier.fillMaxWidth()) {
        Text("Bump visible  (recomposes)")
    }
    OutlinedButton(onClick = { model.revealHidden() }, modifier = Modifier.fillMaxWidth()) {
        Text("Reveal hidden → visible  (forces refresh)")
    }
}
