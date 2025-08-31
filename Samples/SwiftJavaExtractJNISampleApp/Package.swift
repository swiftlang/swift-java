// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

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
    )

  ],
  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],
  targets: [
    .target(
      name: "MySwiftLibrary",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "SwiftKitSwift", package: "swift-java"),
      ],
      exclude: [
        "swift-java.config"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ],
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
      ]
    )
  ]
)
