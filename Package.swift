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
  name: "JavaKit",
  platforms: [
    .macOS(.v13),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
  ],
  products: [
    // ==== JavaKit (i.e. calling Java directly Swift utilities)
    .library(
      name: "JavaKit",
      targets: ["JavaKit"]
    ),

    .library(
      name: "JavaKitJar",
      targets: ["JavaKitReflection"]
    ),

    .library(
      name: "JavaKitNetwork",
      targets: ["JavaKitReflection"]
    ),

    .library(
      name: "JavaKitReflection",
      targets: ["JavaKitReflection"]
    ),

    .library(
      name: "JavaKitVM",
      targets: ["JavaKitVM"]
    ),

    .library(
      name: "JavaTypes",
      targets: ["JavaTypes"]
    ),

    .executable(
      name: "Java2Swift",
      targets: ["Java2Swift"]
    ),

    // ==== jextract-swift (extract Java accessors from Swift interface files)

    .executable(
      name: "jextract-swift",
      targets: ["JExtractSwiftTool"]
    ),

    // Support library written in Swift for SwiftKit "Java"
    .library(
      name: "SwiftKitSwift",
      type: .dynamic,
      targets: ["SwiftKitSwift"]
    ),

    .library(
      name: "JExtractSwift",
      targets: ["JExtractSwift"]
    ),

    // ==== Examples

    .library(
      name: "JavaKitExample",
      type: .dynamic,
      targets: ["JavaKitExample"]
    ),
    .library(
      name: "ExampleSwiftLibrary",
      type: .dynamic,
      targets: ["ExampleSwiftLibrary"]
    ),

  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.0.0"), // TODO: remove, we should not need 'nm' or process callouts
    .package(url: "https://github.com/apple/swift-collections.git", .upToNextMinor(from: "1.1.0")),
  ],
  targets: [
    .macro(
      name: "JavaKitMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaTypes",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaKit",
      dependencies: ["JavaRuntime", "JavaKitMacros", "JavaTypes"],
      exclude: ["generated/JavaKit.swift2java"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitJar",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitJar.swift2java"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitNetwork",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitNetwork.swift2java"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitReflection",
      dependencies: ["JavaKit"],
      exclude: ["generated/JavaKitReflection.swift2java"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitVM",
      dependencies: ["JavaKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "ExampleSwiftLibrary",
      dependencies: [],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "SwiftKitSwift",
      dependencies: [],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),

    .target(
      name: "JavaRuntime",
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
        .swiftLanguageMode(.v5),
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
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "_SubprocessCShims",
      cSettings: [
        .define(
          "_CRT_SECURE_NO_WARNINGS",
          .when(platforms: [.windows])
        )
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .target(
      name: "JExtractSwift",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Collections", package: "swift-collections"),
        "_Subprocess",
        "JavaTypes",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .executableTarget(
      name: "JExtractSwiftTool",
      dependencies: [
        "JExtractSwift",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "JavaKitTests",
      dependencies: ["JavaKit", "JavaKitNetwork", "JavaKitVM"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "JavaTypesTests",
      dependencies: ["JavaTypes"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "JExtractSwiftTests",
      dependencies: [
        "JExtractSwift"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
  ]
)
