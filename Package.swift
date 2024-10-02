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

let javaIncludePath = "\(javaHome)/include"
#if os(Linux)
  let javaPlatformIncludePath = "\(javaIncludePath)/linux"
#elseif os(macOS)
  let javaPlatformIncludePath = "\(javaIncludePath)/darwin"
#else
  #error("Currently only macOS and Linux platforms are supported, this may change in the future.")
// TODO: Handle windows as well
#endif

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
    .package(url: "https://github.com/apple/swift-system", from: "1.0.0"),
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
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitJar",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitJar.swift2java"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitNetwork",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitNetwork.swift2java"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitReflection",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitReflection.swift2java"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitVM",
      dependencies: ["JavaKit"],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
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
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),

    .target(
      name: "JavaRuntime",
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
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

    // FIXME: This is swift-foundation's proposed Subprocess; remove when available
    //  https://github.com/apple/swift-foundation/pull/439
    .target(
      name: "_Subprocess",
      dependencies: [
        "_SubprocessCShims",
        .product(name: "SystemPackage", package: "swift-system"),
      ]
    ),
    .target(
      name: "_SubprocessCShims",
      cSettings: [
        .define(
          "_CRT_SECURE_NO_WARNINGS",
          .when(platforms: [.windows])
        )
      ]
    ),

    .target(
      name: "JExtractSwift",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "_Subprocess",
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
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
  ]
)
