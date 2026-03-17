// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "JavaSieve",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
  ],
  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],
  targets: [
    .target(
      name: "JavaMath",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "JavaUtilJar", package: "swift-java"),
      ],
      exclude: ["swift-java.config"],
      plugins: [
        .plugin(name: "SwiftJavaPlugin", package: "swift-java")
      ]
    ),

    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "JavaSieve",
      dependencies: [
        "JavaMath",
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "JavaUtil", package: "swift-java"),
      ],
      exclude: ["swift-java.config"],
      plugins: [
        .plugin(name: "SwiftJavaPlugin", package: "swift-java")
      ]
    ),
  ]
)
