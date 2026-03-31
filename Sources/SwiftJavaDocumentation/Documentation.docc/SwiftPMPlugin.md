# SwiftJava SwiftPM Plugin

The `SwiftJavaPlugin` automates `swift-java` command line tool invocations during the build process.

## Overview

### Installing the plugin

To install the SwiftPM plugin in your target of choice include the `swift-java` package dependency:

```swift
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "MyProject",

  products: [
    .library(
      name: "JavaKitExample",
      type: .dynamic,
      targets: ["JavaKitExample"]
    ),
  ],

  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-java", from: "..."),
  ],

  targets: [
    .target(
      name: "MyProject",
      dependencies: [
        // ...
      ],
      swiftSettings: [
        // Some swift-java generated code is not yet compatible with swift 6
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        // Include here the plugins you need
        .plugin(name: "JavaCompilerPlugin", package: "swift-java"),
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java"),
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),
  ]
)
```

> Note: Depending on the use case, swift-java may require running Gradle or accessing files outside the Swift package. Ensure that your environment allows Gradle to run, and add the `--disable-sandbox` parameter when invoking the `swift build` command to build the package.
