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

import android.app.Application

class CounterApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Install the Android main-queue executor as early as possible — before
        // any Activity, composable, or @Observable code runs — so Swift's main
        // actor / concurrency work is drained on Android's main Looper.
        //
        // This is the first per-process entry point, and the call also forces
        // the Swift native libraries to load up front (via MySwiftLibrary's
        // static initializer).
        MySwiftLibrary.setupAndroidMainLooper()
    }
}
