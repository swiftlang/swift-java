// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "JavaDependencySampleApp",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
  ],

  products: [
    .executable(
      name: "JavaDependencySample",
      targets: ["JavaDependencySample"]
    ),
  ],

  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],

  targets: [
    .executableTarget(
      name: "JavaDependencySample",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "JavaUtilFunction", package: "swift-java"),
        "JavaCommonsCSV"
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ],
      plugins: [
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),

    .target(
      name: "JavaCommonsCSV",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "JavaUtilFunction", package: "swift-java"),
        .product(name: "JavaUtil", package: "swift-java"),
        .product(name: "JavaIO", package: "swift-java"),
        .product(name: "JavaNet", package: "swift-java"),
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ],
      plugins: [
//        .plugin(name: "SwiftJavaBootstrapJavaPlugin", package: "swift-java"),
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),

    .target(name: "JavaExample"),

  ]
)
