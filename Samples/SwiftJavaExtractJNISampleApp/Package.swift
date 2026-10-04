// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

// Enable C++ interoperability only in the consumer targets, not their dependencies.
let sampleSwiftSettings: [SwiftSetting] =
  [.swiftLanguageMode(.v5)]
  + (Context.environment["CXX_INTEROP"] == "1" ? [.interoperabilityMode(.Cxx)] : [])

let package = Package(
  name: "JExtractJNISampleApp",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(
      name: "MySwiftLibrary",
      type: .dynamic,
      targets: ["MySwiftLibrary"]
    ),
    .library(
      name: "MySwiftDependencyLibrary",
      type: .dynamic,
      targets: ["MySwiftDependencyLibrary"]
    ),
  ],
  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],
  targets: [
    // Separate module to show that we can handle cross module type references (automatic --depends-on)
    .target(
      name: "MySwiftDependencyLibrary",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java")
      ],
      exclude: [
        "swift-java.config"
      ],
      swiftSettings: sampleSwiftSettings,
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
      ]
    ),
    .target(
      name: "MySwiftLibrary",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        "MySwiftDependencyLibrary",
      ],
      exclude: [
        "swift-java.config"
      ],
      swiftSettings: sampleSwiftSettings,
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
      ]
    ),
  ]
)
