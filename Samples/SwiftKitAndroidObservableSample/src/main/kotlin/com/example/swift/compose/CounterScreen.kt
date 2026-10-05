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
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import org.swift.swiftkit.compose.rememberSwiftObservable

/** The basic case: a single observed `Int64` that recomposes on change. */
@Composable
fun CounterScreen() {
    val model = rememberSwiftObservable { CounterModel.init() }

    Text(
        text = "Count: ${model.count}",
        style = MaterialTheme.typography.headlineMedium,
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Button(onClick = { model.increment() }) { Text("Increment") }
        OutlinedButton(onClick = { model.reset() }) { Text("Reset") }
    }
}
