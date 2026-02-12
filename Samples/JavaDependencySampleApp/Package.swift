// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import Foundation
import PackageDescription

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

  if let home = getJavaHomeFromSDKMAN() {
    return home
  }

  if let home = getJavaHomeFromPath() {
    return home
  }

  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}

func getJavaHomeFromSDKMAN() -> String? {
  let home = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".sdkman/candidates/java/current")

  let javaBin = home.appendingPathComponent("bin/java").path
  if FileManager.default.isExecutableFile(atPath: javaBin) {
    return home.path
  }
  return nil
}

func getJavaHomeFromPath() -> String? {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
  task.arguments = ["java"]

  let pipe = Pipe()
  task.standardOutput = pipe

  do {
    try task.run()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else { return nil }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard
      let javaPath = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !javaPath.isEmpty
    else { return nil }

    let resolved = URL(fileURLWithPath: javaPath).resolvingSymlinksInPath()
    return
      resolved
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .path
  } catch {
    return nil
  }
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
    )
  ],

  dependencies: [
    .package(name: "swift-java", path: "../../")
  ],

  targets: [
    .executableTarget(
      name: "JavaDependencySample",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "SwiftJavaConfigurationShared", package: "swift-java"),
        .product(name: "CSwiftJavaJNI", package: "swift-java"),
        .product(name: "JavaUtilFunction", package: "swift-java"),
        "JavaCommonsCSV",
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"]),
        .swiftLanguageMode(.v5),
      ],
      plugins: [
        .plugin(name: "SwiftJavaPlugin", package: "swift-java")
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
        .plugin(name: "SwiftJavaPlugin", package: "swift-java")
      ]
    ),

    .target(name: "JavaExample"),

  ]
)
