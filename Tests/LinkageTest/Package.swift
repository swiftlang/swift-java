// swift-tools-version: 6.1

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

  if let home = getJavaHomeFromLibexecJavaHome(),
    !home.isEmpty
  {
    return home
  }

  if let home = getJavaHomeFromSDKMAN() {
    return home
  }

  if let home = getJavaHomeFromPath() {
    return home
  }

  if ProcessInfo.processInfo.environment["SPI_PROCESSING"] == "1"
    && ProcessInfo.processInfo.environment["SPI_BUILD"] == nil
  {
    return ""
  }
  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}

/// On MacOS we can use the java_home tool as a fallback if we can't find JAVA_HOME environment variable.
func getJavaHomeFromLibexecJavaHome() -> String? {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")

  guard FileManager.default.fileExists(atPath: task.executableURL!.path) else {
    return nil
  }

  let pipe = Pipe()
  task.standardOutput = pipe
  task.standardError = pipe

  do {
    try task.run()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    if task.terminationStatus == 0 {
      return output
    } else {
      return nil
    }
  } catch {
    return nil
  }
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
#elseif os(Windows)
let javaPlatformIncludePath = "\(javaIncludePath)/win32"
#endif

let package = Package(
  name: "linkage-test",
  dependencies: [
    .package(name: "swift-java", path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "LinkageTest",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java")
      ],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ],
      linkerSettings: [
        .unsafeFlags(
          [
            "-L\(javaHome)/lib/server",
            "-Xlinker", "-rpath",
            "-Xlinker", "\(javaHome)/lib/server",
          ],
          .when(platforms: [.linux, .macOS])
        ),
        .unsafeFlags(
          [
            "-L\(javaHome)/lib"
          ],
          .when(platforms: [.windows])
        ),
        .linkedLibrary(
          "jvm",
          .when(platforms: [.linux, .macOS, .windows])
        ),
      ]
    )
  ]
)
