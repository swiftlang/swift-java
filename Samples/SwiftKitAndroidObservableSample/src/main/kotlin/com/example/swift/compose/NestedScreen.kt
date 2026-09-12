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
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import org.swift.swiftkit.compose.rememberSwiftObservable

/**
 * Nested observable objects: `ProfileModel` owns an `AddressModel`.
 *
 * The parent is observed for its own properties (`name`, and the `address`
 * *reference*). To react to changes *inside* the nested object, we observe the
 * child too — `rememberSwiftObservable { profile.address }` — so reads of
 * `address.city` etc. are tracked and field edits recompose.
 */
@Composable
fun NestedScreen() {
    val profile = rememberSwiftObservable { ProfileModel.init() }
    val address = rememberSwiftObservable { profile.address }

    Text("Profile", style = MaterialTheme.typography.titleMedium)
    OutlinedTextField(
        value = profile.name,
        onValueChange = { profile.name = it },
        label = { Text("Name") },
        modifier = Modifier.fillMaxWidth(),
    )

    HorizontalDivider()

    Text("Nested address", style = MaterialTheme.typography.titleMedium)
    Text("One-line: ${address.oneLine}", style = MaterialTheme.typography.bodyMedium)
    OutlinedTextField(
        value = address.street,
        onValueChange = { address.street = it },
        label = { Text("Street") },
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = address.city,
        onValueChange = { address.city = it },
        label = { Text("City") },
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = address.country,
        onValueChange = { address.country = it },
        label = { Text("Country") },
        modifier = Modifier.fillMaxWidth(),
    )

    Button(onClick = { profile.moveToLondon() }, modifier = Modifier.fillMaxWidth()) {
        Text("Move to London (mutates nested object)")
    }
}
