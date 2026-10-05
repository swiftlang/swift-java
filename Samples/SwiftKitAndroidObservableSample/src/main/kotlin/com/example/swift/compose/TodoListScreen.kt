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
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.swift.swiftkit.compose.rememberSwiftObservable

/**
 * Arrays: appending to / removing from the Swift `items: [String]` is an
 * observable change, so the list below recomposes when the array mutates.
 */
@Composable
fun TodoListScreen() {
    val model = rememberSwiftObservable { TodoListModel.init() }

    // Purely-local Compose state for the "new item" text field.
    var newItem by remember { mutableStateOf("") }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        OutlinedTextField(
            value = newItem,
            onValueChange = { newItem = it },
            label = { Text("New item") },
            modifier = Modifier.weight(1f),
        )
        Button(
            onClick = {
                if (newItem.isNotBlank()) {
                    model.add(newItem)
                    newItem = ""
                }
            },
        ) { Text("Add") }
    }

    Text(
        text = "${model.count} item(s)",
        style = MaterialTheme.typography.titleMedium,
    )

    HorizontalDivider()

    for ((index, item) in model.items.withIndex()) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "${index + 1}.  $item",
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
            )
        }
    }

    HorizontalDivider()

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(onClick = { model.removeLast() }) { Text("Remove last") }
        OutlinedButton(onClick = { model.removeAll() }) { Text("Clear") }
    }
}
