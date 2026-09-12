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

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.swift.swiftkit.compose.rememberSwiftObservable

/**
 * Two-way bindings. Each `OutlinedTextField` reads a Swift `String` property
 * and writes it back via the setter. The computed `fullName` / `isComplete`
 * properties update live as you type, proving computed values track their
 * dependencies through the bridge.
 */
@Composable
fun FormScreen() {
    val model = rememberSwiftObservable { FormModel.init() }

    OutlinedTextField(
        value = model.firstName,
        onValueChange = { model.firstName = it },
        label = { Text("First name") },
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = model.lastName,
        onValueChange = { model.lastName = it },
        label = { Text("Last name") },
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = model.email,
        onValueChange = { model.email = it },
        label = { Text("Email") },
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = model.bio,
        onValueChange = { model.bio = it },
        label = { Text("Bio") },
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 96.dp),
    )

    Text(
        text = "Full name: ${model.fullName}",
        style = MaterialTheme.typography.titleMedium,
    )
    Text(
        text = if (model.isComplete) "✅ All required fields complete" else "⚠️ Missing required fields",
        style = MaterialTheme.typography.bodyMedium,
    )

    Button(onClick = { model.clear() }) { Text("Clear") }
}
