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

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/**
 * The set of example screens. Each demonstrates a different facet of bridging
 * a Swift `@Observable` model into Jetpack Compose.
 */
enum class Example(val title: String, val subtitle: String) {
    Counter(
        title = "Counter",
        subtitle = "The basics: one observed Int64, recomposing on change.",
    ),
    Form(
        title = "Two-way Bindings",
        subtitle = "TextFields read/write String properties; computed values update live.",
    ),
    Dashboard(
        title = "Many Observable States",
        subtitle = "Several properties of mixed types driving sliders, switches, steppers.",
    ),
    EdgeCases(
        title = "static / @ObservationIgnored / let",
        subtitle = "Properties that must NOT trigger observation.",
    ),
    Nested(
        title = "Nested Observable Objects",
        subtitle = "A model that owns another @Observable model.",
    ),
    TodoList(
        title = "Arrays",
        subtitle = "Observing append/remove on an array property.",
    );
}

/** Top-level navigation host. `null` selection means we're on the home list. */
@Composable
fun App() {
    var selected by remember { mutableStateOf<Example?>(null) }

    // Hardware/gesture back returns to the home list when inside an example.
    BackHandler(enabled = selected != null) { selected = null }

    when (val example = selected) {
        null -> HomeScreen(onSelect = { selected = it })
        else -> ExampleScaffold(title = example.title, onBack = { selected = null }) {
            when (example) {
                Example.Counter -> CounterScreen()
                Example.Form -> FormScreen()
                Example.Dashboard -> DashboardScreen()
                Example.EdgeCases -> EdgeCasesScreen()
                Example.Nested -> NestedScreen()
                Example.TodoList -> TodoListScreen()
            }
        }
    }
}

@Composable
private fun HomeScreen(onSelect: (Example) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "swift-java × Compose",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(
            text = "Swift @Observable models bridged into Jetpack Compose.",
            style = MaterialTheme.typography.bodyMedium,
        )
        for (example in Example.entries) {
            ExampleCard(example, onClick = { onSelect(example) })
        }
    }
}

@Composable
private fun ExampleCard(example: Example, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = example.title,
                style = MaterialTheme.typography.titleMedium,
            )
            Text(
                text = example.subtitle,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

/** A simple title bar with a back button, plus the example content below. */
@Composable
fun ExampleScaffold(
    title: String,
    onBack: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = onBack) { Text("← Back") }
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 64.dp),
            )
        }
        HorizontalDivider()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            content()
        }
    }
}
