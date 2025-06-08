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
  let javaPlatformIncludePath = "\(javaIncludePath)/win32"
#endif

let package = Package(
  name: "SwiftJava",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    // ==== JavaKit (i.e. calling Java directly Swift utilities)
    .library(
      name: "JavaKit",
      targets: ["JavaKit"]
    ),

    .library(
      name: "JavaRuntime",
      targets: ["JavaRuntime"]
    ),

    .library(
      name: "JavaKitCollection",
      targets: ["JavaKitCollection"]
    ),

    .library(
      name: "JavaKitFunction",
      targets: ["JavaKitFunction"]
    ),

    .library(
      name: "JavaKitJar",
      targets: ["JavaKitJar"]
    ),

    .library(
      name: "JavaKitNetwork",
      targets: ["JavaKitNetwork"]
    ),

    .library(
      name: "JavaKitIO",
      targets: ["JavaKitIO"]
    ),

    .library(
      name: "JavaKitReflection",
      targets: ["JavaKitReflection"]
    ),

    .library(
      name: "JavaTypes",
      targets: ["JavaTypes"]
    ),

    .executable(
      name: "Java2Swift",
      targets: ["Java2Swift"]
    ),

    // ==== Plugin for building Java code
    .plugin(
      name: "JavaCompilerPlugin",
      targets: [
        "JavaCompilerPlugin"
      ]
    ),

    // ==== Plugin for wrapping Java classes in Swift
    .plugin(
      name: "Java2SwiftPlugin",
      targets: [
        "Java2SwiftPlugin"
      ]
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

    // ==== Plugin for wrapping Java classes in Swift
    .plugin(
      name: "JExtractSwiftPlugin",
      targets: [
        "JExtractSwiftPlugin"
      ]
    ),
    .plugin(
      name: "JExtractSwiftCommandPlugin",
      targets: [
        "JExtractSwiftCommandPlugin"
      ]
    ),

    // ==== Examples

    .library(
      name: "ExampleSwiftLibrary",
      type: .dynamic,
      targets: ["ExampleSwiftLibrary"]
    ),

  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),

    // Benchmarking
    .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")),
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
      dependencies: [
        "JavaRuntime",
        "JavaKitMacros",
        "JavaTypes",
        "JavaKitConfigurationShared", // for Configuration reading at runtime
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
          .when(platforms: [.windows])),
        .linkedLibrary(
          "jvm",
          .when(platforms: [.linux, .macOS, .windows])
        ),
      ]
    ),
    .target(
      name: "JavaKitCollection",
      dependencies: ["JavaKit"],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitFunction",
      dependencies: ["JavaKit"],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitJar",
      dependencies: ["JavaKit", "JavaKitCollection"],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitNetwork",
      dependencies: ["JavaKit", "JavaKitCollection"],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitIO",
      dependencies: ["JavaKit", "JavaKitCollection"],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),
    .target(
      name: "JavaKitReflection",
      dependencies: ["JavaKit", "JavaKitCollection"],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ]
    ),

    .plugin(
      name: "JavaCompilerPlugin",
      capability: .buildTool()
    ),

    .plugin(
      name: "Java2SwiftPlugin",
      capability: .buildTool(),
      dependencies: [
        "Java2Swift"
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

    .target(
      name: "JavaKitConfigurationShared"
    ),

    .target(
      name: "JavaKitShared"
    ),

    .target(
      name: "Java2SwiftLib",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        "JavaKit",
        "JavaKitJar",
        "JavaKitReflection",
        "JavaKitNetwork",
        "JavaTypes",
        "JavaKitShared",
        "JavaKitConfigurationShared",
        "_Subprocess", // using process spawning
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"]),
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
        "JavaKitNetwork",
        "Java2SwiftLib",
        "JavaKitShared",
      ],

      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"]),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
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
        "JavaKitShared",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"]),
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

    .plugin(
      name: "JExtractSwiftPlugin",
      capability: .buildTool(),
      dependencies: [
        "JExtractSwiftTool"
      ]
    ),
    .plugin(
      name: "JExtractSwiftCommandPlugin",
      capability: .command(
        intent: .custom(verb: "jextract", description: "Extract Java accessors from Swift module"),
        permissions: [
        ]),
      dependencies: [
        "JExtractSwiftTool"
      ]
    ),

    .testTarget(
      name: "JavaKitTests",
      dependencies: ["JavaKit", "JavaKitNetwork"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
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
      name: "JavaKitMacroTests",
      dependencies: [
        "JavaKitMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "Java2SwiftTests",
      dependencies: ["Java2SwiftLib"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
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
    
    // Experimental Foundation Subprocess Copy
    .target(
      name: "_CShims",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "_Subprocess",
      dependencies: [
        "_CShims",
        .product(name: "SystemPackage", package: "swift-system"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
