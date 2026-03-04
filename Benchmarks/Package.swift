// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "benchmarks",
  platforms: [
    .macOS("15.03")
  ],
  dependencies: [
    .package(path: "../"),
    .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")),
  ],
  targets: [
    .executableTarget(
      name: "JavaApiCallBenchmarks",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "JavaNet", package: "swift-java"),
        .product(name: "Benchmark", package: "package-benchmark"),
      ],
      path: "Benchmarks/JavaApiCallBenchmarks",
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ],
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
      ]
    )
  ]
)
