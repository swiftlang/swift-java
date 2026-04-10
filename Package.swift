// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let swiftJavaJNICoreDep: Package.Dependency
if let localPath = Context.environment["SWIFT_JAVA_JNI_CORE_PATH"] {
  swiftJavaJNICoreDep = .package(path: localPath)
} else {
  swiftJavaJNICoreDep = .package(url: "https://github.com/swiftlang/swift-java-jni-core", branch: "main")
}

let package = Package(
  name: "swift-java",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    // ==== SwiftJava (i.e. calling Java directly Swift utilities)
    .library(
      name: "SwiftJava",
      type: .dynamic,
      targets: ["SwiftJava", "SwiftJavaRuntimeSupport"]
    ),

    .library(
      name: "SwiftJavaConfigurationShared",
      targets: ["SwiftJavaConfigurationShared"]
    ),

    .library(
      name: "JavaUtil",
      targets: ["JavaUtil"]
    ),

    .library(
      name: "JavaUtilFunction",
      targets: ["JavaUtilFunction"]
    ),

    .library(
      name: "JavaUtilJar",
      targets: ["JavaUtilJar"]
    ),

    .library(
      name: "JavaNet",
      targets: ["JavaNet"]
    ),

    .library(
      name: "JavaIO",
      targets: ["JavaIO"]
    ),

    .library(
      name: "JavaLangReflect",
      targets: ["JavaLangReflect"]
    ),

    .executable(
      name: "swift-java",
      targets: ["SwiftJavaTool"]
    ),

    .library(
      name: "SwiftJavaDocumentation",
      targets: ["SwiftJavaDocumentation"]
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
      name: "SwiftJavaPlugin",
      targets: [
        "SwiftJavaPlugin"
      ]
    ),

    .library(
      name: "SwiftRuntimeFunctions",
      type: .dynamic,
      targets: ["SwiftRuntimeFunctions"]
    ),

    .library(
      name: "JExtractSwiftLib",
      targets: ["JExtractSwiftLib"]
    ),

    // ==== Plugin for wrapping Java classes in Swift
    .plugin(
      name: "JExtractSwiftPlugin",
      targets: [
        "JExtractSwiftPlugin"
      ]
    ),

    // ==== Examples

    .library(
      name: "ExampleSwiftLibrary",
      type: .dynamic,
      targets: ["ExampleSwiftLibrary"]
    ),

  ],
  traits: [
    .trait(name: "AndroidCoreLibraryDesugaring")
  ],
  dependencies: [
    swiftJavaJNICoreDep,
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-collections", .upToNextMinor(from: "1.3.0")), // primarily for ordered collections
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.4.0", traits: ["SubprocessFoundation"]),

    // Benchmarking
    .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")),
  ],
  targets: [
    .target(
      name: "SwiftJavaDocumentation",
      dependencies: [
        "SwiftJava",
        "SwiftJavaRuntimeSupport",
        "SwiftRuntimeFunctions",
      ]
    ),

    .macro(
      name: "SwiftJavaMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "SwiftJava",
      dependencies: [
        .product(name: "SwiftJavaJNICore", package: "swift-java-jni-core"),
        "SwiftJavaMacros",
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("ImplicitOpenExistentials"),
      ],
    ),
    .target(
      name: "JavaUtil",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtil",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaUtilFunction",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtilFunction",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaUtilJar",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaUtilJar",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaNet",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaNet",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaIO",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaIO",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaLangReflect",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaLangReflect",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .plugin(
      name: "JavaCompilerPlugin",
      capability: .buildTool()
    ),

    .plugin(
      name: "SwiftJavaPlugin",
      capability: .buildTool(),
      dependencies: [
        "SwiftJavaTool"
      ]
    ),

    .target(
      name: "ExampleSwiftLibrary",
      dependencies: [],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "SwiftJavaRuntimeSupport",
      dependencies: [
        "SwiftJava"
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .target(
      name: "SwiftRuntimeFunctions",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .target(
      name: "SwiftJavaConfigurationShared"
    ),

    .target(
      name: "SwiftJavaShared"
    ),

    .target(
      name: "CodePrinting"
    ),

    .target(
      name: "SwiftJavaToolLib",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        "SwiftJava",
        "JavaUtilJar",
        "JavaLangReflect",
        "JavaNet",
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
        "CodePrinting",
        .product(name: "Subprocess", package: "swift-subprocess"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
      ]
    ),

    .executableTarget(
      name: "SwiftJavaTool",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SystemPackage", package: "swift-system"),
        "SwiftJava",
        "JavaUtilJar",
        "JavaNet",
        "SwiftJavaToolLib",
        "JExtractSwiftLib",
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
        .define(
          "SYSTEM_PACKAGE_DARWIN",
          .when(platforms: [.macOS, .macCatalyst, .iOS, .watchOS, .tvOS, .visionOS])
        ),
        .define("SYSTEM_PACKAGE"),
      ]
    ),

    .target(
      name: "JExtractSwiftLib",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
        .product(name: "SwiftIfConfig", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "SwiftJavaJNICore", package: "swift-java-jni-core"),
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
        "CodePrinting",
      ],
      resources: [
        .process("Resources")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
      ],
      plugins: [
        .plugin(name: "_StaticBuildConfigPlugin")
      ]
    ),

    .executableTarget(
      name: "StaticBuildConfigPluginExecutable",
      dependencies: [
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "SwiftIfConfig", package: "swift-syntax"),
      ]
    ),

    .plugin(
      name: "_StaticBuildConfigPlugin",
      capability: .buildTool(),
      dependencies: [
        "StaticBuildConfigPluginExecutable"
      ]
    ),

    .plugin(
      name: "JExtractSwiftPlugin",
      capability: .buildTool(),
      dependencies: [
        "SwiftJavaTool"
      ]
    ),

    .testTarget(
      name: "SwiftJavaTests",
      dependencies: [
        "SwiftJava",
        "JavaNet",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftJavaMacrosTests",
      dependencies: [
        "SwiftJavaMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftJavaToolLibTests",
      dependencies: [
        "SwiftJavaToolLib",
        "SwiftJavaConfigurationShared",
      ],
      exclude: [
        "SimpleJavaProject"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftJavaConfigurationSharedTests",
      dependencies: ["SwiftJavaConfigurationShared"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "JExtractSwiftTests",
      dependencies: [
        "JExtractSwiftLib",
        "CodePrinting",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftRuntimeFunctionsTests",
      dependencies: [
        "SwiftRuntimeFunctions"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
