# SwiftPM Plugin

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

### Handling cross module Swift type dependencies

Sometimes you may be wanting to treat a specific module with swift-java jextract and expose it to Java, only to find
that it is also exposing types from other modules.

In this situation it is best to also add a `swift-java.config` configuration into the other module, 
and configure it appropriately. Next, when you run the plugin in the main module, it will automatically
pick up the dependency (since your Swift module depends on the other one) and detect there is swift-java configuration there.

This informs the source generator about the location and package of the generated sources and allows it to compile the generated sources in your main module.