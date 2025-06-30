// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "JavaProbablyPrime",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
  ],

  products: [
    .executable(
      name: "JavaProbablyPrime",
      targets: ["JavaProbablyPrime"]
    ),
  ],

  dependencies: [
    .package(name: "swift-java", path: "../../"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
  ],

  targets: [
    .executableTarget(
      name: "JavaProbablyPrime",
      dependencies: [
        .product(name: "JavaKitCollection", package: "swift-java"),
        .product(name: "JavaKit", package: "swift-java"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),
  ]
)
