// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "JavaKitSampleApp",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
  ],

  products: [
    .library(
      name: "JavaKitExample",
      type: .dynamic,
      targets: ["JavaKitExample"]
    )
  ],

  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],

  targets: [
    .target(
      name: "JavaKitExample",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "JavaUtilFunction", package: "swift-java"),
        .product(name: "JavaUtilJar", package: "swift-java"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        .plugin(name: "JavaCompilerPlugin", package: "swift-java"),
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),

    .testTarget(
      name: "JavaKitExampleTests",
      dependencies: [
        "JavaKitExample"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
