# SwiftPM Plugin

The swift-java SwiftPM plugins automate `swift-java` command line tool invocations during the build.

## Overview

There are three plugins, and you only include the ones your target needs:

| Plugin               | What it does                                                                                    |
|----------------------|-------------------------------------------------------------------------------------------------|
| `SwiftJavaPlugin`    | Runs `wrap-java` to generate Swift wrappers for the Java classes listed in `swift-java.config`, resolving any declared Maven `dependencies` first. |
| `JExtractSwiftPlugin`| Runs `jextract` to generate Java bindings (plus Swift thunks) for the target's Swift sources.     |
| `JavaCompilerPlugin` | Compiles `.java` sources kept alongside the Swift target with `javac`.                           |

### Installing the plugin

Add the `swift-java` package dependency and list the plugins on the target:

```swift
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "MyProject",

  products: [
    .library(
      name: "MyProject",
      type: .dynamic,
      targets: ["MyProject"]
    ),
  ],

  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-java", branch: "main"),
  ],

  targets: [
    .target(
      name: "MyProject",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
      ],
      swiftSettings: [
        // Some swift-java generated code is not yet compatible with Swift 6 language mode
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        // Include only the plugins you need
        .plugin(name: "JavaCompilerPlugin", package: "swift-java"),
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java"),
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),
  ]
)
```

> Note: Depending on the use case, swift-java may need to run Gradle or access files outside the Swift package. Resolving Maven `dependencies` in particular requires network access. Pass `--disable-sandbox` to `swift build` in those cases, since the SwiftPM sandbox blocks them. See <doc:SwiftJavaResolve>.

### Handling cross module Swift type dependencies

A module you run jextract over may expose types that come from other modules.

In that case, also add a `swift-java.config` to the other module and configure it
appropriately. When the plugin then runs in the main module, it picks up the
dependency (because your Swift module depends on the other one) and detects the
swift-java configuration there.

This tells the source generator the location and Java package of the other module's
generated sources, and lets it compile the generated sources in your main module.

## See Also

- <doc:SwiftJavaConfigFile>
- <doc:SwiftJavaResolve>
- <doc:SwiftJavaWrapJava>
- <doc:SwiftJavaJextract>
