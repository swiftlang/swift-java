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
  let javaPlatformIncludePath = "\(javaIncludePath)/win32"
#endif

let package = Package(
  name: "JExtractPluginSampleApp",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "JExtractPluginSampleLib",
      type: .dynamic,
      targets: ["JExtractPluginSampleLib"]
    )
  ],
  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],
  targets: [
    .target(
      name: "JExtractPluginSampleLib",
      dependencies: [],
      exclude: [
        "swift-java.config"
      ],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ],
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
        ,
        .plugin(name: "JExtractSwiftCommandPlugin", package: "swift-java")
      ]
    )
  ]
)
