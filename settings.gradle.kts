//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

pluginManagement{
    includeBuild("BuildLogic")
}

rootProject.name = "SwiftKit"
include(
    // The Swift sources we use in our Demo apps, a "Swift library"
    // "SwiftJavaKitExample", // TODO: Gradle doesn't seem to understand Swift 6.0 yet, so we can't do this yet

    "JavaSwiftKitDemo",
)
