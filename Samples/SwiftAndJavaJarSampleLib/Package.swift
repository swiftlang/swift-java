// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "SwiftAndJavaJarSampleLib",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
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
        .product(name: "SwiftRuntimeFunctions", package: "swift-java"),
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
