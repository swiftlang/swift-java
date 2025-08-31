// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "swift-jni",
  products: [
    .library(name: "SwiftJNI", targets: ["SwiftJNI"]),
  ],
  targets: [
    .target(name: "SwiftJNI", dependencies: ["CSwiftJavaJNI"]),
    .target(name: "CSwiftJavaJNI")
  ]
)
