// swift-tools-version: 6.1

import Foundation
import PackageDescription

let package = Package(
  name: "linkage-test",
  platforms: [
    .macOS(.v15)
  ],
  dependencies: [
    .package(name: "swift-java", path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "LinkageTest",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java")
      ]
    ),
    .executableTarget(
      name: "JExtractLinkageTest",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java")
      ],
      exclude: [
        "swift-java.config"
      ],
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
      ]
    ),
  ]
)
