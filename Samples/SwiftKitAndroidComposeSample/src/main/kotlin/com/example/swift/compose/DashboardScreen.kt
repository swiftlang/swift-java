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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.swift.swiftkit.compose.rememberSwiftObservable

/**
 * Many observable states of mixed types on a single model. Each control reads
 * and writes a different property; mutating one should only recompose the
 * widgets that read it.
 */
@Composable
fun DashboardScreen() {
    val model = rememberSwiftObservable { DashboardModel.init() }

    OutlinedTextField(
        value = model.title,
        onValueChange = { model.title = it },
        label = { Text("Title") },
        modifier = Modifier.fillMaxWidth(),
    )

    HorizontalDivider()

    LabeledStepper(
        label = "Counter: ${model.counter}",
        onMinus = { model.decrement() },
        onPlus = { model.increment() },
    )
    LabeledStepper(
        label = "Level: ${model.level}",
        onMinus = { model.levelUp() },  // only "up" provided by the model
        onPlus = { model.levelUp() },
    )
    LabeledStepper(
        label = "Temperature: ${"%.1f".format(model.temperature)}°",
        onMinus = { model.cooler() },
        onPlus = { model.warmer() },
    )

    Text("Progress: ${(model.progress * 100).toInt()}%")
    Slider(
        value = model.progress.toFloat(),
        onValueChange = { model.setProgress(it.toDouble()) },
    )

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text("Enabled")
        Switch(checked = model.isEnabled, onCheckedChange = { model.isEnabled = it })
        Text("Favorite")
        Switch(checked = model.isFavorite, onCheckedChange = { model.isFavorite = it })
    }

    OutlinedButton(onClick = { model.reset() }) { Text("Reset all") }
}

@Composable
private fun LabeledStepper(label: String, onMinus: () -> Unit, onPlus: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        OutlinedButton(onClick = onMinus) { Text("–") }
        Button(onClick = onPlus) { Text("+") }
    }
}
