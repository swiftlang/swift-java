// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
    name: "JavaSieve",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(name: "swift-java", path: "../../"),
    ],
    targets: [
        .target(
            name: "JavaMath",
            dependencies: [
              .product(name: "JavaKit", package: "swift-java"),
              .product(name: "JavaKitJar", package: "swift-java"),
            ],
            swiftSettings: [
              .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
            ],
            plugins: [
              .plugin(name: "Java2SwiftPlugin", package: "swift-java"),
            ]
        ),

        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "JavaSieve",
            dependencies: [
                "JavaMath",
                .product(name: "JavaKit", package: "swift-java"),
                .product(name: "JavaKitCollection", package: "swift-java"),
            ],
            swiftSettings: [
              .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
            ],
            plugins: [
              .plugin(name: "Java2SwiftPlugin", package: "swift-java"),
            ]
        ),
    ]
)
