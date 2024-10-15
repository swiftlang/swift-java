// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "JavaKitSampleApp",
  platforms: [
    .macOS(.v13),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
  ],

  products: [
    .library(
      name: "JavaKitExample",
      type: .dynamic,
      targets: ["JavaKitExample"]
    ),
  ],

  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],

  targets: [
    .target(
      name: "JavaKitExample",
      dependencies: [
        .product(name: "JavaKit", package: "swift-java"),
        .product(name: "JavaKitJar", package: "swift-java"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        .plugin(name: "Java2SwiftPlugin", package: "swift-java"),
        .plugin(name: "JavaCompilerPlugin", package: "swift-java")
      ]
    ),
  ]
)
