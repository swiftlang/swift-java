// swift-tools-version: 6.1

import Foundation
import PackageDescription

// Every runtime product exported from swift-java should be included here.
// This is to verify none of the modules would accidentally pull in Foundation.
// `scripts/run-linkage-test.sh` enforces set equality with the root package.
let runtimeLibraryProducts: [String] = [
  // RUNTIME_LIBRARY_PRODUCTS:START
  "JavaIO",
  "JavaLangReflect",
  "JavaNet",
  "JavaUtil",
  "JavaUtilFunction",
  "JavaUtilJar",
  "SwiftJava",
  "SwiftRuntimeFunctions",
  // RUNTIME_LIBRARY_PRODUCTS:END
]

let runtimeDependencies: [Target.Dependency] = runtimeLibraryProducts.map {
  .product(name: $0, package: "swift-java")
}

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
      dependencies: runtimeDependencies
    ),
    .executableTarget(
      name: "JExtractLinkageTest",
      dependencies: runtimeDependencies,
      exclude: [
        "swift-java.config"
      ],
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
      ]
    ),
  ]
)
