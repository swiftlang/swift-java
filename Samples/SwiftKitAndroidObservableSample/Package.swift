// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "SwiftKitAndroidComposeSample",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(
      name: "MySwiftLibrary",
      type: .dynamic,
      targets: ["MySwiftLibrary"]
    ),
  ],
  dependencies: [
    .package(name: "swift-java", path: "../../"),
    .package(url: "https://github.com/swift-android-sdk/swift-android-native.git", from: "2.0.0")
  ],
  targets: [
    .target(
      name: "MySwiftLibrary",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "AndroidLooper", package: "swift-android-native", condition: .when(platforms: [.android]))
      ],
      exclude: [
        "swift-java.config"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
      ]
    ),
  ]
)
