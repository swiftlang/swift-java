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

import Foundation
import SwiftJava

// Import the json library wrapper:
import OrgAndrejsJson

enum OrgAndrejsJsonTests {
    static func run() async throws {
        print("Now testing Json library...")

        let json = Json(#"{"host": "localhost", "port": 80}"#)

        precondition(json.hasOwnProperty("port"))

        print(json.get("port").toString())
        precondition(json.get("port").as(JavaInteger.self)!.intValue() == 80)

        print("Reading swift-java.config inside OrgAndrejsJson folder...")

        let configPath = String.currentWorkingDirectory.appending("/Sources/OrgAndrejsJson/swift-java.config")

        let config = try JavaClass<Json>().of.url("file://" + configPath)!

        precondition(config.hasOwnProperty("repositories"))

        print(config.toString())
    }
}

private extension String {
    static var currentWorkingDirectory: Self {
        let path = getcwd(nil, 0)!
        defer { free(path) }
        return String(cString: path)
    }
}
