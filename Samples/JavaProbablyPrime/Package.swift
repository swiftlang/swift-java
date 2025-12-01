// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

import class Foundation.ProcessInfo

// Support C++ interoperability mode via CXX_INTEROP environment variable.
// This is used to test that swift-java's public API is compatible with projects
// that enable C++ interoperability mode.
// See: https://github.com/swiftlang/swift-java/issues/391
let cxxInteropEnabled = ProcessInfo.processInfo.environment["CXX_INTEROP"] == "1"

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
        .product(name: "JavaUtil", package: "swift-java"),
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .interoperabilityMode(.Cxx, .when(platforms: cxxInteropEnabled ? [.macOS, .linux] : [])),
      ],
      plugins: [
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),
  ]
)
