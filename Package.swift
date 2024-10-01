// swift-tools-version: 5.9
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
  if let home = try? String(contentsOfFile: path) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }

    return home
  }

  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}
let javaHome = findJavaHome()

let package = Package(
  name: "JavaKit",
  platforms: [
    .macOS(.v13),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
  ],
  products: [
    .library(
      name: "JavaKit",
      type: .dynamic,
      targets: ["JavaKit"]
    ),

    .library(
      name: "JavaKitJar",
      type: .dynamic,
      targets: ["JavaKitReflection"]
    ),

    .library(
      name: "JavaKitNetwork",
      type: .dynamic,
      targets: ["JavaKitReflection"]
    ),

    .library(
      name: "JavaKitReflection",
      type: .dynamic,
      targets: ["JavaKitReflection"]
    ),

    .library(
      name: "JavaKitExample",
      type: .dynamic,
      targets: ["JavaKitExample"]
    ),

    .library(
      name: "JavaKitVM",
      type: .dynamic,
      targets: ["JavaKitVM"]
    ),

    .library(
      name: "JavaTypes",
      type: .dynamic,
      targets: ["JavaTypes"]
    ),

    .library(
      name: "JExtractSwift",
      type: .dynamic,
      targets: ["JExtractSwift"]
    ),

    .executable(
      name: "Java2Swift",
      targets: ["Java2Swift"]
    ),

    .executable(
      name: "jextract-swift",
      targets: ["JExtractSwiftTool"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
  ],
  targets: [
    .macro(
      name: "JavaKitMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "JavaTypes"
    ),
    .target(
      name: "JavaKit",
      dependencies: ["JavaRuntime", "JavaKitMacros", "JavaTypes"],
      exclude: ["generated/JavaKit.swift2java"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ]
    ),
    .target(
      name: "JavaKitJar",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitJar.swift2java"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ]
    ),
    .target(
      name: "JavaKitNetwork",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitNetwork.swift2java"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ]
    ),
    .target(
      name: "JavaKitReflection",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitReflection.swift2java"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ]
    ),
    .target(
      name: "JavaKitVM",
      dependencies: ["JavaKit"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ],
      linkerSettings: [
        .unsafeFlags(
          [
            "-L\(javaHome)/lib/server",
            "-Xlinker",
            "-rpath",
            "-Xlinker",
            "\(javaHome)/lib/server",
          ]
        ),
        .linkedLibrary("jvm"),
      ]
    ),
    .target(
      name: "JavaKitExample",
      dependencies: ["JavaKit"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ]
    ),

    .target(
      name: "JavaRuntime",
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ]
    ),

    .executableTarget(
      name: "Java2Swift",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "JavaKit",
        "JavaKitJar",
        "JavaKitReflection",
        "JavaKitNetwork",
        "JavaKitVM",
        "JavaTypes",
      ],
      swiftSettings: [
        .enableUpcomingFeature("BareSlashRegexLiterals")
      ]
    ),

    .target(
      name: "JExtractSwift",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "JavaTypes",
      ]
    ),

    .executableTarget(
      name: "JExtractSwiftTool",
      dependencies: [
        "JExtractSwift",
      ]
    ),

    .testTarget(
      name: "JavaKitTests",
      dependencies: ["JavaKit", "JavaKitNetwork", "JavaKitVM"]
    ),

    .testTarget(
      name: "JavaTypesTests",
      dependencies: ["JavaTypes"]
    ),

    .testTarget(
      name: "JExtractSwiftTests",
      dependencies: [
        "JExtractSwift"
      ],
      swiftSettings: [
        .unsafeFlags(["-I\(javaHome)/include", "-I\(javaHome)/include/darwin"])
      ]
    ),
  ]
)
