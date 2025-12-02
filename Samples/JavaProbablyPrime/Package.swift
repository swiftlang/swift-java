// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

import class Foundation.FileManager
import class Foundation.ProcessInfo

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    return home
  }

  // This is a workaround for envs (some IDEs) which have trouble with
  // picking up env variables during the build process
  let path = "\(FileManager.default.homeDirectoryForCurrentUser.path()).java_home"
  if let home = try? String(contentsOfFile: path, encoding: .utf8) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }

    return home
  }

  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}
let javaHome = findJavaHome()

let javaIncludePath = "\(javaHome)/include"
#if os(Linux)
  let javaPlatformIncludePath = "\(javaIncludePath)/linux"
#elseif os(macOS)
  let javaPlatformIncludePath = "\(javaIncludePath)/darwin"
#elseif os(Windows)
  let javaPlatformIncludePath = "\(javaIncludePath)/win32)"
#endif

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
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"]),
        .interoperabilityMode(.Cxx, .when(platforms: cxxInteropEnabled ? [.macOS, .linux] : [])),
      ],
      plugins: [
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),
  ]
)
