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
#else
  // TODO: Handle windows as well
  #error("Currently only macOS and Linux platforms are supported, this may change in the future.")
#endif

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
        .product(name: "CJNI", package: "swift-java"),
        .product(name: "JavaUtilFunction", package: "swift-java"),
        "JavaCommonsCSV"
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"]),
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
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"]),
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
