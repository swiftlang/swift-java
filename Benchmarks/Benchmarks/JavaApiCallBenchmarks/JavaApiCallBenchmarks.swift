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

import Benchmark
import Foundation
import SwiftJava
import JavaNet

@MainActor let benchmarks = {
    var jvm: JavaVirtualMachine {
        get throws {
            try .shared()
        }
    }
    Benchmark("Simple call to Java library") { benchmark in
        for _ in benchmark.scaledIterations {
            let environment = try jvm.environment()

            let urlConnectionClass = try JavaClass<URLConnection>(environment: environment)
            blackHole(urlConnectionClass.getDefaultAllowUserInteraction())
        }
    }
}
